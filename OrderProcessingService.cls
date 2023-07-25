public class OrderProcessingService implements Queueable,Database.AllowsCallouts{    
     
    // Global Variables
    private batch_log__c log = new batch_log__c();
    public Boolean success;
    public Integer parsedOrderCount = 0;
    Item__c[] products = [ SELECT 	SKU__c,
                                                External_ID__c
                                        FROM    Item__c
                                        WHERE   Account = 'Cool Games Dev'  		
                                    ];

    //Inner clases are used to deserialize incoming  JSON
    public class Orders{
        public List<Order> orders;
    }

    public class Order {
        public Object token;
        public String external_callback;
        public String id;
        public String s_added;
        public String customer_email;
        public String customer_phone;
        public String amount_subtotal;
        public String amount_discount;
        public String amount_taxes;
        public String amount_shipping;
        public String amount_total;
        public String shipping_name;
        public String shipping_address;
        public String shipping_address2;
        public String shipping_city;
        public String shipping_state;
        public String shipping_postal_code;
        public String shipping_country;
        public String shipping_service;
        public String signature;
        public Boolean order_priority;
        public List<Products> products;

    }

    public class Products {
        public String code;
        public String name;
        public Integer quantity;
        public String amount_product;
    }
   

    /*
    *********************************************************
    @Method Name    : execute (Main)
    @description    : Main method that will get Cool Games Dev JSON, Deserialize it into a Orders record and create s Records from that information
    @param          : context
    @return         : Null
    ********************************************************
    */
    public void execute(QueueableContext context) {
        //Instantiate a new Orders Object to hold records from the JSON that will later be processed
        Orders orders = new Orders();    
        try{
            // Calls the method to retrieve the JSON string
            String responseBody = getOrders();
            // Deserializes the JSON string into the Orders object and its dependents
            orders = (Orders)JSON.deserialize(responseBody, Orders.class); 
        } catch(Exception e) {
            // Logs the error message and creates a batch_log__c object if an exception is thrown during the deserialization
            batch_log__c errorLog = new batch_log__c();
            errorLog.Type__c = 'Error';
            errorLog.start_dt__c = system.today();
            errorLog.message__c =  'An Error Occured in Apex Class _Orders_Service: ' + '\nError Message: '+ e.getMessage();
            insert errorLog;
        }
        // Calls the processOrders method, passing in the Orders object, to calculate the sales
        processOrders(orders);    
    }

    
    /*
    *********************************************************
    @Method Name    : getOrders 
    @description    : A method that retrieves JSON from an endpoint using a GET request and returns the response body.
    @return         : String - the response body from the HTTP GET request
    ********************************************************
    */
        private String getOrders() {
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setHeader('Accept', 'application/json');
            request.setHeader('Content-Type','application/json;charset=UTF-8');
            request.setEndpoint('https://CoolGamesDev.com/Orders');
            request.setMethod('GET');
            request.setTimeout(60000);
            HttpResponse response = http.send(request);
            system.debug('Response Status Code:'+ response.getStatusCode());
            system.debug('Response Body:'+ response.getBody());
            return response.getBody();    
    }
    

    /*
    *********************************************************
    @Method Name    : processOrders
    @description    : Processes a list of  Orders and creates Sales records from them
    @param          : orders (Orders) - the list of  Orders to process
    @return         : None
    ********************************************************
    */
    @TestVisible private void processOrders(Orders orders){
        // Create a staging sales list for the sales that will be upserted
        list<sales__c> ordersToUpsert = new list<sales__c>();
        //Loop through each order in the list of Orders from the  JSON
        for(Order order :orders.orders){
            //Create a list of sales records that can be created from this order(multiple items per order require multiple sales records)
            sales__c[] sList = buildSalesObject(order);
            //Loop through each sales record in that list and add it to the staging list to be upserted
            for(sales__c s : sList){
            	ordersToUpsert.add(s);
            }
            parsedOrderCount++;
        }
        //Upsert the staging list
        try {
            // Check if the number of orders in the JSON matches the number of orders processed
            Integer jsonOrderCount = orders.orders.size();
            if(jsonOrderCount == parsedOrderCount){
                // Create a batch log record to record the order count
                batch_log__c countLog = new batch_log__c();
            	countLog.Type__c = 'Order Count';
                countLog.start_dt__c = system.today();
                countLog.message__c = String.valueOf(jsonOrderCount);
                insert countLog;
             }else{
                 //Send error log about parsed orders not matching JSON total
                 batch_log__c errorLog = new batch_log__c();
                 errorLog.Type__c = 'Error';
                 errorLog.start_dt__c = system.today();
                 errorLog.message__c =  'An Error Occured in Apex Class Orders_Service: Count from JSON = ' + String.valueOf(jsonOrderCount) + ' and Count from Parsed Orders = ' + String.valueOf(parsedOrderCount) + ' Do not match';
                 insert errorLog;
             }
            // Upsert the Total Sales records
            upsert ordersToUpsert external_id__c;
            
      	}catch (DmlException e) {
            //Send error log if records could not be upserted
        	batch_log__c errorLog = new batch_log__c();
            errorLog.Type__c = 'Error';
            errorLog.start_dt__c = system.today();
            errorLog.message__c =  'An Error Occured in Apex Class Orders_Service: Could not Upsert Orders: ' + '\nError Message: '+ e.getMessage();
            insert errorLog;
            }
    }


    /*
    *********************************************************
    @Method Name    : buildSalesObject
    @description    : Method used to parse the items within an order and create sales records based on it
    @param          : order
    @return         : List of Sales
    ********************************************************
    */
    @TestVisible private List<sales__c> buildSalesObject(Order order){
        //Create a staging list for the possible sales records that will be created
        List<sales__c> tempSList = new List<sales__c>();
        // Instaciate a Map to keep track of identical skus in the same order
        Map < String, Integer > multipleItemsMap = new Map < String, Integer > ();
        //Split the customer name into first,(possibly middle) and last name
        String[] name = order.shipping_name.split(' ');
        //Loop through each item in the order
        for(integer i = 0; i<order.products.size(); i++){
            //Create a new sales record
      		sales__c s = new sales__c();
        	  //Create the Total Sales record from the order record
              s.address_1__c          = order.shipping_address;
              s.Address_2__c          = order.shipping_address2;
              s.channel__c            = 'Website';
              s.channel_detail__c	  = 'Cool Games Dev';
              s.city__c               = order.shipping_city;
              s.country_code__c       = order.shipping_country;
              s.email__c              = order.customer_email;
              s.first_name__c         = name[0];
              s.fulfillment_type__c   = 'E-Com';
              s.item__c               = order.products[i].name;
              s.last_name__c          = ifblank(name[name.size()-1],'');
              s.lob__c                = 'Distribution';
              s.order_number__c       = order.id;
              s.postal_code__c        = order.shipping_postal_code;
              s.price__c              = Decimal.valueOf(ifblank(order.products[i].amount_product, ''));
              s.qty__c                = order.products[i].quantity;
              s.sales_type__c         = 'B2C';
              s.sku__c                = productIDtoSKU(order.products[i].code);
              s.source__c             = 'Cool Games Dev';
              s.state_provence__c     = order.shipping_state;
              s.tax__c                = Decimal.valueOf(ifblank(order.amount_taxes, ''));
              s.sales__c              = Decimal.valueOf(ifblank(order.amount_total, ''));
              s.transaction__c        = 'Purchase';
              s.transaction_date__c   = Date.valueOf(order.ts_added);
              s.packing_slip_url__c   = order.external_callback;
              s.signature__c          = order.signature;
              s.shipping_amount__c    = Decimal.valueOf(ifblank(order.amount_shipping, ''));
              s.shipping_service__c   = order.shipping_service;
              s.priority__c           = order.order_priority;
                // Check if the key "s.sku__c" is present in the map "multipleItemsMap"
                if (!multipleItemsMap.containsKey(s.sku__c)) {
                    // If the key is not present, add it with a value of 0
                    multipleItemsMap.put(s.sku__c, 0);
                    // Set the value of "s.External_Id__c" as "order.id + '_' + s.sku__c"
                    s.External_Id__c = order.id + '_' + s.sku__c;
                } else {
                    // If the key is present, increment its value by 1
                    Integer updatedValue = multipleItemsMap.get(s.sku__c) + 1;
                    // Update the value in the map
                    multipleItemsMap.put(s.sku__c, updatedValue);
                    // Set the value of "s.External_Id__c" as "order.id + '_' + s.sku__c + '_' + updatedValue"
                    s.External_Id__c = order.id + '_' + s.sku__c + '_' + updatedValue;
                }                
            //Add the record to the staging list
            tempSList.add(s);
        }
        //Return the full list to be add to the upsterting list
        return tempSList;
    }
    

    /*
    *********************************************************
    @Method Name    : ifblank
    @Description    : Handles an empty or null string by returning a default value or an empty string
    @Param          : in_string - the input string to be checked
                    null_value - the default value to return if the input string is empty or null
    @Return         : Trimmed input string or default value
    ********************************************************
    */
    private string ifblank(string in_string, string null_value){
        string null_txt = '';
        if ( null_value != null ){
                null_txt = null_value.trim();
            }
        // Check if string is a null value, if it is return a empty string
        if (in_string == null ){
            return(null_txt);
        }
        string temp = in_string.trim();
        if ( temp.length() < 1 ){
            return(null_txt);
        }
        return(temp);
    }
    

    /*
    *********************************************************
    @Method Name    : ProductIDtoSKU
    @Description    : Matches the incoming  product ID to the SKU sku and returns it
    @Param          : ProductID - the  product ID to be matched
    @Return         : SKU sku or null if no match found
    ********************************************************
    */
    private String productIDtoSKU(String ProductID){
        //Loop through each  Item from the query at the beginning of the class
        for(Sourcing_Item__c _Product: _products){
            //If the Item's ExternalID and the  Product ID match up return the SKU sku
            if(_product.External_ID__c == ProductID){
                return _product.SKU__c;
            }
        }
        batch_log__c errorLog = new batch_log__c();
        //Send error log if records could not be matched
            errorLog.Type__c = 'Error';
            errorLog.start_dt__c = system.today();
            errorLog.message__c =  'An Error Occured in Apex Class Orders_Service: Could not find matching SKU for product: ' + ProductID;
            insert errorLog;
        return null;
    }
}