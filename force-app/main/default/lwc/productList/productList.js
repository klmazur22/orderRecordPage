import { LightningElement, wire, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import getOrderableProducts from '@salesforce/apex/OrderController.getOrderableProducts';
import addToOrder from '@salesforce/apex/OrderController.addToOrder';
import { publish, MessageContext } from 'lightning/messageService';
import itemAddedChannel from '@salesforce/messageChannel/Item_Added__c';

const COLUMNS = [
    { label: 'Name', fieldName: 'Name', type: 'text' },
    { label: 'List Price', fieldName: 'UnitPrice', type: 'currency' },
    { label: '', type: 'button', initialWidth: 100, typeAttributes: 
        {iconName: 'utility:add', label: 'Add', name: 'Add'}
    }
];

const RECORDS_PER_PAGE = 10;

export default class OrderController extends LightningElement {
    @api recordId;
    columns = COLUMNS;
    products = [];

    @wire(getOrderableProducts, { currentOrderId: '$recordId' })
    wiredProducts(result) {
        let { data, error } = result;
        if (data) { 
            let rows = [];
            for (var i = 0; i < data.length; i++) {
                //processing data so it can be displayed in datatable correctly
                let row = {};
                row.Id = data[i].Id;
                row.Name = data[i].Product2.Name;
                row.UnitPrice = data[i].UnitPrice;
                rows.push(row);
            }
            this.products = rows;
            
            if(this.products.length < 1){
                const event = new ShowToastEvent({
                    "title": "Orderable products not found",
                    "message": "Make sure that pricebook is assigned to this order.",
                    variant: 'Warning'
                });
                this.dispatchEvent(event);
            }
            
            this.gotoPage(this.currentPage);
        } else if (error) {
            this.products = [];
            const event = new ShowToastEvent({
                "title": "Error",
                "message": "Failed to retrieve available products: " + error.body.message,
                variant: 'error'
            });
            this.dispatchEvent(event);
        }
    }
    
    //needed for LMS
    @wire(MessageContext)
    messageContext;

    handleAddProduct(event){
        addToOrder({
            currentOrderId : this.recordId,
            pricebookEntryId : event.detail.row.Id
        })
            .then(() => {
                //publish event to Lightning Message Service to update another LWC
                publish(this.messageContext, itemAddedChannel, {});
            })
            .catch(error => {
                const event = new ShowToastEvent({
                    "title": "Error",
                    "message": "Error while adding item to order: " + error.body.message,
                    variant: 'error'
                });
                this.dispatchEvent(event);
            })
    }

    /*-----PAGINATION STARTS-----*/
    
    displayAmount = RECORDS_PER_PAGE;

    // Partial JSON array of sourceData variable to bind to data table
    pagedData;
    // Current page of results on display
    currentPage = 1;
    // Current maximum pages in sourceData set
    maxPages = 1;
    // Indicators to disable the paging buttons
    disabledPreviousButton = false;
    disabledNextButton = false;
    // Loading indicator
    loading = false;

    handleButtonNext() {
        var nextPage = this.currentPage + 1;
        var maxPages =  this.getMaxPages();
        if(nextPage > 0 && nextPage <= maxPages) {
            this.gotoPage(nextPage);
        }
    }

    handleButtonPrevious() {
        var nextPage = this.currentPage - 1;
        var maxPages =  this.getMaxPages();
        if(nextPage > 0 && nextPage <= maxPages) {
            this.gotoPage(nextPage);
        }
    }

    getMaxPages() {
        // There will always be 1 page, at least
        var result = 1;
        // Number of elements on sourceData
        var arrayLength;
        // Number of elements on sourceData divided by number of rows to display in table (can be a float value)
        var divideValue;
        // Ensure sourceData has a value
        if(this.products) {
            arrayLength = this.products.length;
            // Float value of number of pages in data table
            divideValue = arrayLength / this.displayAmount;
            // Round up to the next Integer value for the actual number of pages
            result = Math.ceil(divideValue); 
        }
        this.maxPages = result;
        return result;
    }

    // Change page
    gotoPage(pageNumber) {
        var recordStartPosition, recordEndPosition;
        var i, arrayElement;        // Loop helpers
        var maximumPages = this.maxPages;
        
        this.loading = true;

        maximumPages = this.getMaxPages();

        // Validate that desired page number is available
        if( pageNumber > maximumPages || pageNumber < 0 ) {
            // Invalid page change. Do nothing
            this.loading = false;
            return;
        }

        this.disabledPreviousButton = false;
        this.disabledNextButton = false;

        if(this.products) {
            // Empty the data source used 
            this.pagedData = [];
            // Start the records at the page position
            recordStartPosition = this.displayAmount * (pageNumber - 1);
            // End the records at the record start position with an extra increment for the page size
            recordEndPosition = recordStartPosition + parseInt(this.displayAmount, 10);
            // Loop through the selected page of records
            for ( i = recordStartPosition; i < recordEndPosition; i++ ) {
                arrayElement = this.products[i];
                if(arrayElement) {
                    // Add data element for the data to bind
                    this.pagedData.push(arrayElement);
                }
            }
            // Set global current page to the new page
            this.currentPage = pageNumber;
            // If current page is the final page then disable the next button
            if(maximumPages === this.currentPage) {
                this.disabledNextButton = true;
            }
            // If current page is the first page then disable the previous button
            if(this.currentPage === 1) {
                this.disabledPreviousButton = true;
            }
            this.loading = false;
        }
    }
    /*-----PAGINATION ENDS-----*/
}