import { LightningElement, wire, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import { refreshApex } from '@salesforce/apex';
import getOrderItems from '@salesforce/apex/OrderController.getOrderItems';
import increaseQuantity from '@salesforce/apex/OrderController.increaseQuantity';
import decreaseQuantity from '@salesforce/apex/OrderController.decreaseQuantity';
import { subscribe, MessageContext } from 'lightning/messageService';
import itemAddedChannel from '@salesforce/messageChannel/Item_Added__c';
import isOrderActivated from '@salesforce/apex/OrderController.isOrderActivated';
import confirmOrder from '@salesforce/apex/OrderController.confirmOrder';

const COLUMNS = [
    { label: 'Name', fieldName: 'Name', type: 'text' },
    { label: 'List Price', fieldName: 'UnitPrice', type: 'currency'},
    { label: 'Quantity', fieldName: 'Quantity', type: 'number' },
    { label: 'Total Price', fieldName: 'TotalPrice', type: 'currency' },
    { label: '', type: 'button', initialWidth: 75, typeAttributes: 
        {iconName: 'utility:add', label: '', name: 'Add', disabled: false}
    },
    { label: '', type: 'button', initialWidth: 75, typeAttributes: 
        {iconName: 'utility:dash', label: '', name: 'Remove', disabled: false}
    }
];

export default class OrderController extends LightningElement {
    subscription = null;
    @api recordId;
    columns = COLUMNS;
    products = [];
    disableButtons = true;
    
    _wiredResult; //Wired Apex result so it can be refreshed programmatically

    @wire(getOrderItems, { currentOrderId: '$recordId' })
    wiredProducts(result) {
        this._wiredResult = result;
        let { data, error } = result;
        if (data) {
            let rows = [];
            for (var i = 0; i < data.length; i++) {
                //processing data so it can be displayed in datatable correctly
                let row = {};
                row.Id = data[i].Id;
                row.Name = data[i].Product2.Name;
                row.UnitPrice = data[i].UnitPrice;
                row.Quantity = data[i].Quantity;
                row.TotalPrice = data[i].TotalPrice;
                rows.push(row);
            }
            this.products = rows;
        } else if (error) {
            this.products = [];
            const event = new ShowToastEvent({
                "title": "Error",
                "message": "Failed to retrieve order items: " + error.body.message,
                variant: 'error'
            });
            this.dispatchEvent(event);
        }
    }

    _isOrderActivated;
    
    @wire(isOrderActivated, { currentOrderId: '$recordId' })
    wireIsOrderActivated(result) {
        this._isOrderActivated = result;
        let { data, error } = result;
        if (error) {
            this.disableButtons = true;
            throw new Error('Order status not defined');
        }
        //enable buttons only if order is not activated and there is at least one order item
        else this.disableButtons = data && (this.products.length > 0);
    }

    handleQuantityChange(event){
        if (event.detail.action.name === 'Add'){
            increaseQuantity({ orderItemId : event.detail.row.Id })
                .then(() => {
                    return refreshApex(this._wiredResult);
                })
                .catch(error => {
                    const event = new ShowToastEvent({
                        "title": "Error",
                        "message": "Failed to increase quantity: " + error.body.message,
                        variant: 'error'
                    });
                    this.dispatchEvent(event);
                })
        }
        else if (event.detail.action.name === 'Remove'){
            decreaseQuantity({ orderItemId : event.detail.row.Id })
                .then(() => {
                    return refreshApex(this._wiredResult);
                })
                .catch(error => {
                    const event = new ShowToastEvent({
                        "title": "Error",
                        "message": "Failed to decrease quantity: " + error.body.message,
                        variant: 'error'
                    });
                    this.dispatchEvent(event);
                })
        }
    }
    
    /*-----LMS STARTS-----*/
    @wire(MessageContext)
    messageContext;

    subscribeToMessageChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                itemAddedChannel,
                (message) => this.handleRefreshMyOrder(message)
            );
        }
    }

    handleRefreshMyOrder(){
        return refreshApex(this._wiredResult);
    }

    connectedCallback() {
        this.subscribeToMessageChannel();
    }
    /*-----LMS ENDS-----*/

    handleConfirm(){
        confirmOrder({currentOrderId: this.recordId})
        .then(() => {
            const event = new ShowToastEvent({
                "title": "Success!",
                "message": "Order confirmed and activated",
                variant: 'success'
            });
            this.dispatchEvent(event);
            return refreshApex(this._isOrderActivated);
        })
        .catch(error => {
            const event = new ShowToastEvent({
                "title": "Error",
                "message": "Failed to confirm order: " + error.body.message,
                variant: 'error'
            });
            this.dispatchEvent(event);
        })
    }
}