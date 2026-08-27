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
  /// Set when the server tells the SDK to stop (HTTP 410). Nothing is queued or run afterwards.
  private(set) var isStopped = false

  init() {
    taskQueue.maxConcurrentOperationCount = 1 // Ensure tasks are processed sequentially
    taskQueue.isSuspended = true // Suspend task execution until initialization is complete
  }

  func addTaskAfterInit(taskName: String, timeout: TimeInterval = 10.0, _ task: @escaping (_ completion: @escaping () -> Void) -> Void) {
    if isStopped {
      Logger.verbose("SDK is stopped, ignoring task: '\(taskName)'")
      return
    }

    Logger.verbose("Task added to queue: '\(taskName)'. Queue size after adding: \(taskQueue.operationCount + 1)")

    let operation = BlockOperation {
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
  /// resumed to let the cancelled ones drain and release. Cancelled operations never run.
  func stop() {
    isStopped = true

    let discarded = taskQueue.operationCount
    taskQueue.cancelAllOperations()
    taskQueue.isSuspended = false
    Logger.verbose("SDK stopped, task queue cleared. Pending tasks discarded: \(discarded)")
  }

  /// Tasks still held by the queue.
  var queuedTaskCount: Int { taskQueue.operationCount }

  func initializeComplete() {
    // Registration reports completion even when it failed, so this runs after a 410 stop too.
    // Returning keeps the log stream honest: "Task queue initialized" right after "SDK stopped"
    // reads as if the SDK resumed, and Android never emits it in that situation.
    if isStopped { return }

    isInitialized = true
    Logger.verbose("Task queue initialized. Processing queued tasks.")
    taskQueue.isSuspended = false // Resume task execution after initialization is complete
  }
  func reset() {
    Logger.verbose("Resetting task queue state")
    // Prevent new operations from starting, then cancel pending ones.
    taskQueue.isSuspended = true
    taskQueue.cancelAllOperations()
    isInitialized = false
    isStopped = false
    Logger.verbose("Task queue reset completed")
  }
}
