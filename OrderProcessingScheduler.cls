global class OrderProcessingScheduler implements Schedulable {
    // The `execute` method is called by the system when the scheduled job is triggered
    global void execute(SchedulableContext sc) {
        // Create a new instance of the `OrderProcessingService` class
        OrdersService ws = new OrdersService();
        // Add the `OrderProcessingService` instance to the system's job queue
        System.enqueueJob(ws);
    }
}