# OrderProcessingScheduler and OrderProcessingService Classes

##Overview

The `OrderProcessingScheduler` and `OrderProcessingService` classes synergistically execute regular fetching and processing of order data from an external API, designed specifically for the "Cool Games Dev" business context. The `OrderProcessingScheduler` class is the heartbeat for the scheduling and triggering of the `OrderProcessingService`, which, in turn, is the workhorse that performs the core tasks of data retrieval, processing, and Salesforce record creation.

## OrderProcessingScheduler Class

The `OrderProcessingScheduler` is a Salesforce Apex class that adopts the `Schedulable` interface. It takes the responsibility of scheduling the `OrderProcessingService` class execution at determined intervals, essentially functioning as an internal clock for the order processing service.

## OrderProcessingService Class

The `OrderProcessingService` class is the powerhouse performing the tasks of data retrieval and processing. It employs the `Queueable` and `Database.AllowsCallouts` interfaces, which facilitate it to conduct asynchronous calls and HTTP callouts respectively. This class fetches JSON data from an external API, deserializes it into `Order` records, and consequently creates `Sales` records in Salesforce. Additionally, it adeptly manages errors and logs them for future troubleshooting.

## Class Methods Descriptions

### OrderProcessingScheduler Class

- `execute(SchedulableContext sc)`: This method, integral to the `Schedulable` interface, triggers the `OrderProcessingService` for execution when the scheduler fires.

### OrderProcessingService Class

- `execute(QueueableContext context)`: This is the entry point for asynchronous processing in the `OrderProcessingService` class. This method gets called when the `OrderProcessingScheduler` triggers the service.

- `fetchOrderData()`: This method handles the HTTP callout to the external API to retrieve JSON formatted order data.

- `deserializeOrderData(String jsonData)`: A utility method responsible for deserializing the fetched JSON order data into `Order` records. This method takes the JSON string as an input and returns a list of `Order` objects.

- `createSalesRecords(List<Order> orders)`: This method handles the creation of Salesforce `Sales` records from the deserialized `Order` objects. It takes a list of `Order` objects as input.

- `handleError(Exception e)`: An error handling method that logs exceptions for further investigation. This method takes an exception as an input and creates an `Error_Log__c` record in Salesforce with the details of the error.

## How To Use
Schedule the OrderProcessingScheduler using Salesforce's System.schedule method. 

## Notes
All Object Names, Methods and Variables have been changed from the original classes for security purposes.
