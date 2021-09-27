/**
* @author Kyrylo Mazur
* @description Test class for OrderController
* @date 9/2021
*/
@IsTest private class OrderControllerTest {
    
    static final Integer PRODUCTS_NUMBER = 3;
    static final Id pricebookId = Test.getStandardPricebookId();

    @TestSetup private static void setup(){
        List<Product2> productsList = new List<Product2>();
        for (Integer i = 0; i < PRODUCTS_NUMBER; i++){
        	productsList.add(new Product2(Name = 'Product' + i, ProductCode = String.valueOf(i), IsActive = true));
        }
        insert productsList;
        
        List<PricebookEntry> pricebookEntriesList = new List<PricebookEntry>();
        for (Integer i = 0; i < PRODUCTS_NUMBER; i++)
        	pricebookEntriesList.add(new PricebookEntry(Pricebook2Id = pricebookId, 
                                                        Product2Id = productsList[i].Id,
                                                        UnitPrice = 10*i+1,
                                                        IsActive = true));
        insert pricebookEntriesList;
        
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        Order order = new Order(Name ='Test Order', AccountId = acc.Id, Pricebook2Id = Test.getStandardPricebookId(), Status = 'New', EffectiveDate = Date.Today());
        insert order;
    }

    @IsTest
    static void testGetOrderableProducts() {
        Order order = [SELECT Id FROM Order LIMIT 1];
        Test.startTest();
        System.assertEquals(PRODUCTS_NUMBER, OrderController.getOrderableProducts(order.Id).size());
        Test.stopTest();
    }

    @IsTest
    static void testAddToOrder() {
        Order order = [SELECT Id FROM Order LIMIT 1];
        List<PricebookEntry> pricebookEntriesList = [SELECT Id, Product2Id FROM PricebookEntry LIMIT :PRODUCTS_NUMBER];
        Test.startTest();
            for (Integer i = 0; i < PRODUCTS_NUMBER; i++){
                //test addToOrder with new items
                OrderController.addToOrder(order.Id, pricebookEntriesList[i].Id);
            }
            //test getOrderItems
            System.assertEquals(PRODUCTS_NUMBER, OrderController.getOrderItems(order.Id).size());
            //test addToOrder with existant item
            OrderController.addToOrder(order.Id, pricebookEntriesList[0].Id);
            System.assertEquals(PRODUCTS_NUMBER, OrderController.getOrderItems(order.Id).size());
            OrderItem item = [SELECT Id, Quantity FROM OrderItem WHERE Product2Id =: pricebookEntriesList[0].Product2Id];
            System.assertEquals(2, item.Quantity);
        Test.stopTest();
    }

    @IsTest
    static void testIncreaseQuantity() {
        Order order = [SELECT Id FROM Order LIMIT 1];
        List<PricebookEntry> pricebookEntriesList = [SELECT Id, Product2Id FROM PricebookEntry LIMIT :PRODUCTS_NUMBER];
        Test.startTest();
            //creating item
            OrderController.addToOrder(order.Id, pricebookEntriesList[0].Id);
            OrderItem item = [SELECT Id, Quantity FROM OrderItem WHERE Product2Id =: pricebookEntriesList[0].Product2Id];
            System.assertEquals(1, item.Quantity);
            //increasing quantity to 2
            OrderController.increaseQuantity(item.Id);
            item = [SELECT Id, Quantity FROM OrderItem WHERE Product2Id =: pricebookEntriesList[0].Product2Id];
            System.assertEquals(2, item.Quantity);
        Test.stopTest();
    }

    @IsTest
    static void testDecreaseQuantity() {
        Order order = [SELECT Id FROM Order LIMIT 1];
        List<PricebookEntry> pricebookEntriesList = [SELECT Id, Product2Id FROM PricebookEntry LIMIT :PRODUCTS_NUMBER];
        Test.startTest();
            //creating item
            OrderController.addToOrder(order.Id, pricebookEntriesList[0].Id);
            //increasing quantity to 2
            OrderController.addToOrder(order.Id, pricebookEntriesList[0].Id);
            OrderItem item = [SELECT Id, Quantity FROM OrderItem WHERE Product2Id =: pricebookEntriesList[0].Product2Id];
            System.assertEquals(2, item.Quantity);
            //decreasing quantity to 0 => deleting item
            OrderController.decreaseQuantity(item.Id);
            OrderController.decreaseQuantity(item.Id);
            System.assertEquals(0, OrderController.getOrderItems(order.Id).size());
        Test.stopTest();
    }
    
    @IsTest
    static void testConfirmOrderAndIsOrderActivated() {
        Order order = [SELECT Id FROM Order LIMIT 1];
        //check that order is not Activated
        System.assert(!OrderController.isOrderActivated(order.Id));
        List<PricebookEntry> pricebookEntriesList = [SELECT Id, Product2Id FROM PricebookEntry LIMIT :PRODUCTS_NUMBER];
        //setting up mock
        OrderController.addToOrder(order.Id, pricebookEntriesList[0].Id);
        OrderControllerMock calloutMock = new OrderControllerMock();
        Test.setMock(HttpCalloutMock.class, calloutMock);
        Test.startTest();
        //calling only method with calloud inside startTest/stopTest so DML operations remain in another block
            OrderController.confirmOrder(order.Id);
        Test.stopTest();
        //check that order is Activated now
        System.assert(OrderController.isOrderActivated(order.Id));
    }
}