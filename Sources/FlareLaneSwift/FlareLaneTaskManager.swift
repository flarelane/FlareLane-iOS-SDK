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
    Logger.verbose("TaskQueue", "task added", ["name": taskName, "size": taskQueue.operationCount + 1])

    let operation = BlockOperation {
      let semaphore = DispatchSemaphore(value: 0)
      var taskCompleted = false

      Logger.verbose("TaskQueue", "task executing", ["name": taskName, "size": self.taskQueue.operationCount])

      // Execute the task on a background thread
      DispatchQueue.global(qos: .userInitiated).async {
        task {
          taskCompleted = true
          Logger.verbose("TaskQueue", "task completed", ["name": taskName])
          semaphore.signal() // Signal that the task is complete
        }
      }

      // Set up the timeout
      DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeout) {
        if !taskCompleted {
          Logger.error("TaskQueue", "task timed out", ["name": taskName, "timeout": timeout])
          semaphore.signal() // Signal that the timeout has occurred
        }
      }

      semaphore.wait() // Wait for the task or timeout to complete

      // Ensure task completion is called even if the semaphore wait fails
      if !taskCompleted {
        Logger.error("TaskQueue", "task did not complete but semaphore released", ["name": taskName])
      }
    }

    taskQueue.addOperation(operation)
  }

  func initializeComplete() {
    isInitialized = true
    Logger.info("TaskQueue", "queue initialized, processing queued tasks")
    taskQueue.isSuspended = false // Resume task execution after initialization is complete
  }
  func reset() {
    Logger.info("TaskQueue", "reset started")
    // Prevent new operations from starting, then cancel pending ones.
    taskQueue.isSuspended = true
    taskQueue.cancelAllOperations()
    isInitialized = false
    Logger.info("TaskQueue", "reset completed")
  }
}
