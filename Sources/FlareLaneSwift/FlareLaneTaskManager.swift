//
//  FlareLaneTaskManager.swift
//  FlareLane
//
//  Created by MinHyeok Kim on 8/14/24.
//

import Foundation

class FlareLaneTaskManager {
  static let shared = FlareLaneTaskManager()

  private var taskQueue = OperationQueue()
  private var isInitialized = false

  /// Guards `stopped` together with the queue mutation it decides on. `stop()` runs on a URLSession
  /// callback thread while tasks are added from the caller's thread, so checking the flag and
  /// enqueueing have to be one step — otherwise a task can slip in after `stop()` already cancelled
  /// everything and resumed the queue, and it would run.
  private let stateLock = NSLock()
  /// Set when the server tells the SDK to stop (HTTP 410). Nothing is queued or run afterwards.
  private var stopped = false

  init() {
    taskQueue.maxConcurrentOperationCount = 1 // Ensure tasks are processed sequentially
    taskQueue.isSuspended = true // Suspend task execution until initialization is complete
  }

  /// - Parameter onCancelled: run instead of the task when it will never run because the SDK
  ///   stopped. Tasks that owe the host app a result must pass one — a Flutter `await` or a React
  ///   Native callback resolves only from inside the task body, so dropping it silently leaves the
  ///   host app waiting forever. Always invoked on the main thread, exactly once, and never for a
  ///   task that ran.
  func addTaskAfterInit(taskName: String, timeout: TimeInterval = 10.0, onCancelled: (() -> Void)? = nil, _ task: @escaping (_ completion: @escaping () -> Void) -> Void) {
    // Shared with the completion block below to tell "ran" from "cancelled" without holding a
    // reference to the operation, which the queue may already have released by then.
    var didStart = false

    let operation = BlockOperation {
      didStart = true
      let semaphore = DispatchSemaphore(value: 0)
      var taskCompleted = false

      Logger.verbose("Executing task: '\(taskName)'. Queue size before execution: \(self.taskQueue.operationCount)")

      // Execute the task on a background thread
      DispatchQueue.global(qos: .userInitiated).async {
        task {
          taskCompleted = true
          Logger.verbose("Task '\(taskName)' completed successfully.")
          semaphore.signal() // Signal that the task is complete
        }
      }

      // Set up the timeout
      DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeout) {
        if !taskCompleted {
          Logger.verbose("Task '\(taskName)' timed out.")
          semaphore.signal() // Signal that the timeout has occurred
        }
      }

      semaphore.wait() // Wait for the task or timeout to complete

      // Ensure task completion is called even if the semaphore wait fails
      if !taskCompleted {
        Logger.error("Task '\(taskName)' did not complete properly, but semaphore was released.")
      }
    }

    // A cancelled operation never runs its block, but the queue still calls its completionBlock
    // once it drains. That is where a discarded task answers its caller.
    if let onCancelled = onCancelled {
      operation.completionBlock = {
        guard !didStart else { return }
        DispatchQueue.main.async(execute: onCancelled)
      }
    }

    stateLock.lock()
    defer { stateLock.unlock() }

    if stopped {
      Logger.verbose("SDK is stopped, cancelling task: '\(taskName)'")
      if let onCancelled = onCancelled { DispatchQueue.main.async(execute: onCancelled) }
      return
    }

    Logger.verbose("Task added to queue: '\(taskName)'. Queue size after adding: \(taskQueue.operationCount + 1)")
    taskQueue.addOperation(operation)
  }

  /// Drop everything pending and ignore new tasks, for the rest of this process.
  ///
  /// The queue has to be emptied, not just closed to new work: with `requestPermissionOnLaunch`
  /// the queue stays suspended until the permission alert is answered, so whatever is already
  /// queued would fire the moment the user taps — long after the project turned out to be gone.
  ///
  /// Cancelling alone is not enough either. A suspended OperationQueue keeps holding its
  /// operations (and whatever they captured) even after `cancelAllOperations`, so the queue is
  /// resumed to let the cancelled ones drain and release. Draining is also what fires each
  /// cancelled task's `onCancelled`, so no caller is left waiting on a result.
  func stop() {
    stateLock.lock()
    stopped = true
    let cancelled = taskQueue.operationCount
    taskQueue.cancelAllOperations()
    taskQueue.isSuspended = false
    stateLock.unlock()

    Logger.verbose("SDK stopped, task queue cleared. Pending tasks cancelled: \(cancelled)")
  }

  /// Tasks still held by the queue.
  var queuedTaskCount: Int { taskQueue.operationCount }

  func initializeComplete() {
    // Registration reports completion even when it failed, so this runs after a 410 stop too.
    // Returning keeps the log stream honest: "Task queue initialized" right after "SDK stopped"
    // reads as if the SDK resumed, and Android never emits it in that situation.
    stateLock.lock()
    if stopped {
      stateLock.unlock()
      return
    }

    isInitialized = true
    taskQueue.isSuspended = false // Resume task execution after initialization is complete
    stateLock.unlock()

    Logger.verbose("Task queue initialized. Processing queued tasks.")
  }
  func reset() {
    Logger.verbose("Resetting task queue state")

    stateLock.lock()
    let cancelled = taskQueue.operationCount
    // Cancel then resume, in that order. Suspending first would leave the queue holding the
    // cancelled operations: their memory stays retained and their `onCancelled` never fires, so a
    // caller waiting on resetDevice() would hang exactly as it would on stop(). Draining first and
    // continuing with a fresh suspended queue avoids both.
    taskQueue.cancelAllOperations()
    taskQueue.isSuspended = false
    taskQueue = OperationQueue()
    taskQueue.maxConcurrentOperationCount = 1
    taskQueue.isSuspended = true
    isInitialized = false
    stopped = false
    stateLock.unlock()

    Logger.verbose("Task queue reset completed. Pending tasks cancelled: \(cancelled)")
  }
}
