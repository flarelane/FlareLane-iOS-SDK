//
//  FlareLaneTaskManager.swift
//  FlareLane
//
//  Created by MinHyeok Kim on 8/14/24.
//

import Foundation

class FlareLaneTaskManager {
  static let shared = FlareLaneTaskManager()

  // Bounded so a queue that never opens (registration failing while the app
  // keeps calling the SDK) cannot grow without limit. The newest task is
  // rejected rather than the oldest dropped, because OperationQueue cannot
  // drop its oldest — and Android matches this behavior for parity.
  static let maxPendingTasks = 100

  private var taskQueue = OperationQueue()
  private var isInitialized = false

  // Set when the server answered 410 on a device endpoint; see stop().
  // Guarded by a lock: tasks are added from arbitrary caller threads while
  // stop() arrives on a URLSession callback thread.
  private let stateLock = NSLock()
  private var isStopped = false

  init() {
    taskQueue.maxConcurrentOperationCount = 1 // Ensure tasks are processed sequentially
    taskQueue.isSuspended = true // Suspend task execution until initialization is complete
  }

  func addTaskAfterInit(taskName: String, timeout: TimeInterval = 10.0, _ task: @escaping (_ completion: @escaping () -> Void) -> Void) {
    // A flood guard, not an exact quota: a burst of concurrent adds may briefly
    // overshoot by the number of racing threads, which is fine — the point is
    // that the queue can never grow without limit.
    if taskQueue.operationCount >= Self.maxPendingTasks {
      Logger.error("Task queue is full (\(Self.maxPendingTasks) pending), ignoring task: '\(taskName)'")
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

    // Checked and enqueued under one lock: a stop() landing between a separate
    // check and the add would let this operation slip past cancelAllOperations
    // and run on the already-resumed queue, breaking the post-410 contract.
    stateLock.lock()
    defer { stateLock.unlock() }
    if isStopped {
      Logger.verbose("SDK is stopped, ignoring task: '\(taskName)'")
      return
    }
    taskQueue.addOperation(operation)
  }

  /// Stop for the rest of this process: the server answered 410 on a device
  /// endpoint, meaning this project or device is gone and will not come back
  /// within this run. Pending tasks are dropped so they cannot fire later,
  /// new tasks are refused, and the next app launch starts clean.
  ///
  /// The queue is resumed after cancelling: a suspended OperationQueue keeps
  /// holding its operations (and whatever they captured) even after
  /// cancelAllOperations, so it must run to let the cancelled ones drain and
  /// release. Cancelled operations never execute.
  func stop() {
    stateLock.lock()
    isStopped = true
    let discarded = taskQueue.operationCount
    taskQueue.cancelAllOperations()
    taskQueue.isSuspended = false
    stateLock.unlock()
    Logger.verbose("SDK stopped, task queue cleared. Pending tasks discarded: \(discarded)")
  }

  func initializeComplete() {
    isInitialized = true
    Logger.verbose("Task queue initialized. Processing queued tasks.")
    taskQueue.isSuspended = false // Resume task execution after initialization is complete
  }
  func reset() {
    Logger.verbose("Resetting task queue state")
    // Cancelled operations only leave operationCount once they run to their
    // finished state, and a suspended queue never starts them — they would sit
    // there forever, counting against maxPendingTasks. Resume briefly so they
    // drain (cancelled operations never execute), then suspend for the next init.
    taskQueue.cancelAllOperations()
    taskQueue.isSuspended = false
    taskQueue.waitUntilAllOperationsAreFinished()
    taskQueue.isSuspended = true
    isInitialized = false
    stateLock.lock()
    // Deliberately lifted here: reset() is the explicit re-initialization entry
    // point, which must be allowed to try again. If the project is still gone,
    // the very next registration's 410 re-stops.
    isStopped = false
    stateLock.unlock()
    Logger.verbose("Task queue reset completed")
  }
}
