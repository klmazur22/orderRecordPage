/**
* @author Kyrylo Mazur
* @description Apex controller for Lightning Web Components: myOrder, productList
* @date 9/2021
*/
public with sharing class OrderController {
    
    /*******************************************************************************************************
    * @description check if order status is 'Activated
    * @param currentOrderId the Id of order reviewed
    * @return boolean: true if order status is 'Activated', otherwise - false
    */
    @AuraEnabled(cacheable=true)
    public static Boolean isOrderActivated(Id currentOrderId){
        return [SELECT Status
                FROM Order 
                WHERE Id =: currentOrderId].Status == 'Activated';
    }

    /*******************************************************************************************************
    * @description get list of products which can be added to order
    * @param currentOrderId the Id of order reviewed
    * @return list of Pricebook Entries from current order's pricebook
    */
    @AuraEnabled(cacheable=true)
    public static List<PricebookEntry> getOrderableProducts(Id currentOrderId){
        Order currentOrder = [SELECT Pricebook2Id 
                              FROM Order 
                              WHERE Id =: currentOrderId LIMIT 1];
        List<PricebookEntry> pricebookEntriesList = [SELECT Id, Product2Id, Product2.Name, UnitPrice
                                                     FROM PricebookEntry 
                                                     WHERE Pricebook2Id =: currentOrder.Pricebook2Id 
                                                     AND IsActive = true
                                                     ORDER BY Product2.Name];
        return pricebookEntriesList;
    }
    
    /*******************************************************************************************************
    * @description get list of items related to current order
    * @param currentOrderId the Id of order reviewed
    * @return List of active Order Items related to current order
    */
    @AuraEnabled(cacheable=true)
    public static List<OrderItem> getOrderItems(Id currentOrderId){
        List<OrderItem> orderItemList = [SELECT Id, Product2.Name, UnitPrice, Quantity, TotalPrice
                                         FROM OrderItem 
                                         WHERE OrderId =: currentOrderId
                                         AND Quantity > 0
                                         ORDER BY Product2.Name];
        return orderItemList;
    }
    
    /*******************************************************************************************************
    * @description add product as order item to current order
    * @param currentOrderId the Id of order reviewed
    * @param pricebookEntryId the Id of Pricebook Entry which needs to be added
    */
    @AuraEnabled
    public static void addToOrder(Id currentOrderId, Id pricebookEntryId){
        if([SELECT Status FROM Order WHERE Id =: currentOrderId].Status == 'Activated') throw new OrderChangeException('Cannot edit activated order.');
        else {
            PricebookEntry chosenProduct = [SELECT Id, Product2Id, UnitPrice 
                                            FROM PricebookEntry 
                                            WHERE Id =: pricebookEntryId];
            List<OrderItem> items = [SELECT Id, Quantity 
                                     FROM OrderItem 
                                     WHERE OrderId =: currentOrderId 
                                     AND Product2Id =: chosenProduct.Product2Id LIMIT 1];
            if (items.size() > 0){
                items[0].Quantity++;
                update items;
            }
            else {
                OrderItem newItem = new OrderItem (PricebookEntryId = chosenProduct.Id, 
                                                   OrderId = currentOrderId, 
                                                   Product2Id = chosenProduct.Product2Id, 
                                                   Quantity = 1, 
                                                   UnitPrice = chosenProduct.UnitPrice);
                insert newItem;
            }
        }
    }
    
    /*******************************************************************************************************
    * @description increase the value of order item's quantity field
    * @param orderItemId the Id of Order Item which needs to be updated
    */
    @AuraEnabled
    public static void increaseQuantity(Id orderItemId){
        if([SELECT Status FROM Order WHERE Id =: [SELECT OrderId FROM OrderItem WHERE Id =:orderItemId].OrderId].Status == 'Activated') throw new OrderChangeException('Cannot edit activated order.');
        else{
            OrderItem item = [SELECT Id, Quantity 
                              FROM OrderItem 
                              WHERE Id =: orderItemId];
            item.Quantity++;
            update item;
        }
    }
    
    /*******************************************************************************************************
    * @description decrease the value of order item's quantity field, and delete record if quantity becomes less than 1
    * @param orderItemId the Id of Order Item which needs to be updated
    */
    @AuraEnabled
    public static void decreaseQuantity(Id orderItemId){
        if([SELECT Status FROM Order WHERE Id =: [SELECT OrderId FROM OrderItem WHERE Id =:orderItemId].OrderId].Status == 'Activated') throw new OrderChangeException('Cannot edit activated order.');
        else {
            OrderItem item = [SELECT Id, Quantity 
                              FROM OrderItem 
                              WHERE Id =: orderItemId];
            if (item.Quantity <= 1)
                delete item;
            else {
                item.Quantity--;
                update item;
            }
        }
    }
    
    /*******************************************************************************************************
    * @description send request to External System with order information; if successful - change order status to "Activated"
    * @param orderItemId the Id of Order Item which needs to be updated
    */
    @AuraEnabled
    public static void confirmOrder(Id currentOrderId){
        Order currentOrder = [SELECT Account.AccountNumber, OrderNumber, Type, Status FROM Order WHERE Id =: currentOrderId];
        List<OrderItem> orderItems = [SELECT Product2.Name, UnitPrice, Quantity, Product2.ProductCode
                                      FROM OrderItem 
                                      WHERE OrderId =: currentOrderId
                                      AND Quantity > 0
                                      ORDER BY Product2.Name];
        if(orderItems.size() < 1) throw new OrderConfirmationException('Cannot confirm order without order items.');
        else if(currentOrder.Status != 'Activated') {
            HttpRequest request = new HttpRequest();
            request.setEndpoint('https://order-confirmation-external-system.requestcatcher.com');
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json;charset=UTF-8');
            
            OrderForConfirmation body = new OrderForConfirmation();
            body.accountNumber = String.isNotBlank(currentOrder.Account.AccountNumber) ? currentOrder.Account.AccountNumber : '';
            body.orderNumber = String.isNotBlank(currentOrder.OrderNumber) ? currentOrder.OrderNumber : '';
            body.type = String.isNotBlank(currentOrder.Type) ? currentOrder.Type : '';
            body.status = String.isNotBlank(currentOrder.Status) ? currentOrder.Status : '';
            body.orderProducts = new List<OrderProduct>();
            for(OrderItem item : orderItems)
            {
                OrderProduct orderProduct = new OrderProduct();
                orderProduct.name = String.isNotBlank(item.Product2.Name) ? item.Product2.Name : ''; 
                orderProduct.code = String.isNotBlank(item.Product2.ProductCode) ? item.Product2.ProductCode : '';
                orderProduct.unitPrice = item.UnitPrice; 
                orderProduct.quantity = item.Quantity.intValue();
                body.orderProducts.add(orderProduct);
            }
            
            request.setBody(JSON.serializePretty(body));
            
            Http http = new Http();
            HTTPResponse res = http.send(request);
            if(res.getStatusCode() != 200) throw new ExternalSystemException('External System rejected confirmation request.');
            else {
                currentOrder.Status = 'Activated';
                update currentOrder;
            }
        }
    }
    
    /*******************************************************************************************************
    * @description classes which are needed to follow the assignment's structure and fields name
    */
    public class OrderForConfirmation {
        public String accountNumber;
        public String orderNumber;
        public String type;
        public String status;
        List<OrderProduct> orderProducts;
    }
    public class OrderProduct {
        public String name;
        public String code;
        public Double unitPrice;
        public Integer quantity;
    }
    
    public class ExternalSystemException extends Exception{}
    public class OrderChangeException extends Exception{}
    public class OrderConfirmationException extends Exception{}
}