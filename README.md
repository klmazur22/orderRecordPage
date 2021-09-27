# orderRecordPage
Record page with 2 custom LWC which show the list of orderable products, and ordered items

## 🚀 How To Start
To test the Order record page:

Click on the App Launcher -> Contracts.

Create a Contract record (it will be needed to create Order record).

Move Contract to "Activated" status.

Click on the App Launcher -> Order.

Create an Order record.

When the Order record page is opened, you will see a warning that there no oderable products found. It's fine. It happens because there no Pricebook assigned.

Near the Order products, click on "Add Products".

Choose any Product -> Next -> Quantity = 1 -> Save. In this way Pricebook is assigned. Then you will be able to remove an item added to the order.

Refresh the page.

From this moment, components are ready to be tested!

## External System URL (requestcatcher)
https://order-confirmation-external-system.requestcatcher.com
