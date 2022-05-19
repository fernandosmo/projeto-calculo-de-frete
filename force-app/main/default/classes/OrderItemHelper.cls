public with sharing class OrderItemHelper {
    public OrderItemHelper() {}

    public static List<Order> CalcTotalVolumeWeightQuantity(Map<Id, OrderItem> oldRecords, Map<Id, OrderItem> newRecords) {
        
        List<OrderItem> orderItemModifiedList = new List<OrderItem>();

        for (OrderItem newOrderItem : newRecords.values()) {
            OrderItem oldOrderItem = oldRecords.get(newOrderItem.id);

            if((newOrderItem.Quantity != oldOrderItem.Quantity) 
            || (newOrderItem.Weight__c != oldOrderItem.Weight__c) 
            || (newOrderItem.Volume__c != oldOrderItem.Volume__c)){
                orderItemModifiedList.add(newOrderItem);
            }
        }

        return CalcTotalVolumeWeightQuantity(orderItemModifiedList);
    }

    public static List<Order> CalcTotalVolumeWeightQuantity(List<OrderItem> orderItemList) {

        Set<Id> orderIdSet = new Set<Id>();
        for(OrderItem orderItem : orderItemList){
            orderIdSet.add(orderItem.Id);
        }

        List<AggregateResult> orderItemTotals = getAggregatedValues(orderIdSet);

        List<Order> orderList = findingDcFreight(orderItemTotals);
        
        return orderList;
    }

    public static List<AggregateResult> getAggregatedValues(Set<Id> orderIdSet) {
        
        List<AggregateResult> orderItemTotals = [
            SELECT OrderId, SUM(Quantity) totalItems, SUM(Weight__c) totalWeight, SUM(Volume__c) totalVolume
            FROM OrderItem 
            WHERE Id IN: OrderIdSet
            GROUP BY OrderId
        ];
        
        return orderItemTotals;
    }

    public static List<Order> findingDcFreight(List<AggregateResult> orderItemTotals) {

        Set<Id> orderIds = new Set<Id>();

        for(AggregateResult result : orderItemTotals) {
            Id orderId = (Id)result.get('OrderId');

            orderIds.add(orderId);
        }

        List<Order> orderList = new List<Order>([
            SELECT Id, AccountId, DistributionCenter__c, Freight__c, TotalFreight__c, Status
            FROM Order 
            WHERE Id IN: OrderIds
        ]);

        Set<Id> accountIds = new Set<Id>();

        for(Order order : orderList) {
            accountIds.add(order.AccountId);
        }

        List<Account> accountList = new List<Account>([
            SELECT Id, CEP__c, City__c, City__r.State__c
            FROM Account
            WHERE Id IN: accountIds
        ]);

        List<Freight__c> freightListComplete = new List<Freight__c>([
            SELECT Id, Name, CEP__c, City__c, State__c, DistributionCenter__c, FreightByVolume__c, FreightByWeight__c, Freightbase__c
            FROM Freight__c
        ]);
        Set<Id> dcIds = new Set<Id>();

        for(Freight__c freight : freightListComplete) {
            dcIds.add(freight.DistributionCenter__c);
        }

        List<DistributionCenter__c> dcList = new List<DistributionCenter__c>([
            SELECT Id, Name
            FROM DistributionCenter__c
            WHERE Id IN: dcIds
        ]);

        Map<Id, Order> orderMap = new Map<Id, Order>();

        for (AggregateResult result : orderItemTotals) {
            
            Id orderId = (Id)result.get('OrderId');
            
            Decimal totalItems = (Decimal)result.get('totalItems');
            Decimal totalWeight = (Decimal)result.get('totalWeight');
            Decimal totalVolume = (Decimal)result.get('totalVolume');

            for(Order order : orderList) {

                if(order.Id == orderId) {

                    Map<Id, Freight__c> freightListToChoose = new Map<Id, Freight__c>();

                    for(Account account : accountList) {

                        if(account.Id == order.AccountId){
                            
                            for( DistributionCenter__c dc : dcList) {
                                
                                List<Freight__c> freightList = new List<Freight__c>();

                                for(Freight__c freight : freightListComplete) {
                                    if(freight.DistributionCenter__c == dc.Id){
                                        freightList.add(freight);
                                    }
                                }

                                Freight__c betterFreightDc = new Freight__c(FreightBase__c = 0);
                       
                                if(betterFreightDc.FreightBase__c == 0) {
                                    for(Freight__c freight : freightList) {
                                        if(freight.DistributionCenter__c == dc.Id && freight.CEP__c == account.CEP__c) {
                                            betterFreightDc = freight;
                                            freightListToChoose.put(betterFreightDc.Id, betterFreightDc);
                                        }
                                    }
                                }
                                if(betterFreightDc.FreightBase__c == 0) {
                                    for(Freight__c freight : freightList) {
                                        if(freight.DistributionCenter__c == dc.Id && freight.City__c == account.City__c) {
                                            betterFreightDc = freight;
                                            freightListToChoose.put(betterFreightDc.Id, betterFreightDc);       
                                        }
                                    }
                                }
                                if(betterFreightDc.FreightBase__c == 0) {
                                    for(Freight__c freight : freightList) {
                                        if(freight.DistributionCenter__c == dc.Id && freight.State__c == account.City__r.State__c) {
                                            betterFreightDc = freight;
                                            freightListToChoose.put(betterFreightDc.Id, betterFreightDc);
                                        }
                                    }
                                }                                
                            }
                        }
                    }

                    Decimal freightValue = 999999999;

                    Freight__c freightChoosed = new Freight__c();

                    for (Freight__c freight : FreightListToChoose.values()) {
                        Decimal totalFreightByVolumeOrder = 0;
                        Decimal totalFreightByWeightOrder = 0;
                        Decimal totalFreightByQuantityOrder = 0; 

                        if (freight.FreightByVolume__c != null && freight.FreightByWeight__c != null && freight.FreightBase__c != null) {
                            totalFreightByVolumeOrder = totalVolume * freight.FreightByVolume__c;
                            totalFreightByWeightOrder = totalWeight * freight.FreightByWeight__c;
                            totalFreightByQuantityOrder = totalItems * freight.FreightBase__c;
                        }

                        if (totalFreightByVolumeOrder >= totalFreightByWeightOrder && totalFreightByVolumeOrder >= totalFreightByQuantityOrder) {

                            if (freightValue > totalFreightByVolumeOrder) {
                                freightValue = totalFreightByVolumeOrder;
                                FreightChoosed = freight;
                            }
                        } 
                        else if (totalFreightByWeightOrder > totalFreightByVolumeOrder && totalFreightByWeightOrder >= totalFreightByQuantityOrder) {

                            if (freightValue > totalFreightByWeightOrder) {
                                freightValue = totalFreightByWeightOrder;
                                FreightChoosed = freight;
                            }
                        }
                        else if (totalFreightByQuantityOrder > totalFreightByVolumeOrder && totalFreightByQuantityOrder > totalFreightByWeightOrder) {

                            if (freightValue > totalFreightByQuantityOrder) {
                                freightValue = totalFreightByQuantityOrder;
                                FreightChoosed = freight;
                            }
                        }
                    }

                    if(freightChoosed != null) {
                        if(freightValue != 999999999){
                            order.TotalFreight__c = freightValue;
                        }
                    
                        order.Freight__c = freightChoosed.Id;
                        order.DistributionCenter__c = freightChoosed.DistributionCenter__c;
                    }

                    orderMap.put(orderId, order);
                }
            }
        }

        return orderMap.values();
    }
}