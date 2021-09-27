/**
* @author Kyrylo Mazur
* @description Mock for external callout in OrderController.confirmOrder method
* @date 9/2021
*
*/
@isTest
global class OrderControllerMock implements HttpCalloutMock {
    
    global HTTPResponse respond(HTTPRequest req) {
        System.assertEquals(true, req.getEndpoint().contains('https://order-confirmation-external-system.requestcatcher.com'));
        System.assertEquals('POST', req.getMethod());
        String body = req.getBody();
        System.assertEquals(true, body.contains('type'));
        System.assertEquals(true, body.contains('status'));
        System.assertEquals(true, body.contains('orderNumber'));
        System.assertEquals(true, body.contains('accountNumber'));
        System.assertEquals(true, body.contains('orderProducts'));
        System.assertEquals(true, body.contains('unitPrice'));
        System.assertEquals(true, body.contains('quantity'));
        System.assertEquals(true, body.contains('name'));
        System.assertEquals(true, body.contains('code'));
        
        // Create a fake response
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setStatusCode(200);
        res.setBody('{"status":"success"}');
        return res;
    }
}