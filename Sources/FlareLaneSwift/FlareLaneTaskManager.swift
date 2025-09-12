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

  init() {
    taskQueue.maxConcurrentOperationCount = 1 // Ensure tasks are processed sequentially
    taskQueue.isSuspended = true // Suspend task execution until initialization is complete
  }

  func addTaskAfterInit(taskName: String, timeout: TimeInterval = 10.0, _ task: @escaping (_ completion: @escaping () -> Void) -> Void) {
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

  func initializeComplete() {
    isInitialized = true
    Logger.verbose("Task queue initialized. Processing queued tasks.")
    taskQueue.isSuspended = false // Resume task execution after initialization is complete
  }

  func reset() {
    Logger.verbose("Resetting task queue state")

    // Cancel all pending operations
    taskQueue.cancelAllOperations()

    // Reset initialization state
    isInitialized = false
    taskQueue.isSuspended = true // Suspend task execution until re-initialization

    Logger.verbose("Task queue reset completed")
  }
}
