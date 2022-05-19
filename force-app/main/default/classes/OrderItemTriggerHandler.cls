public with sharing class OrderItemTriggerHandler {
    
    List<OrderItem> oldRecords {get; set;} // Trigger.old
    List<OrderItem> newRecords {get; set;} // Trigger.new
    Map<Id, OrderItem> oldMap {get; set;} // Trigger.oldMap
    Map<Id, OrderItem> newMap {get; set;} // Trigger.newMap

    public OrderItemTriggerHandler(List<OrderItem> oldRecords, List<OrderItem> newRecords, Map<Id, OrderItem> oldMap, Map<Id, OrderItem> newMap) {
        this.oldRecords = oldRecords;
        this.newRecords = newRecords;
        this.oldMap = oldMap;
        this.newMap = newMap;
    }

    public void afterInsert(){
        List<Order> orderList = OrderItemHelper.CalcTotalVolumeWeightQuantity(this.newRecords);

        if(!orderList.isEmpty()){
            update orderList;
        }
    }
    
    public void beforeUpdate(){
        List<Order> orderList = OrderItemHelper.CalcTotalVolumeWeightQuantity(this.oldMap, this.newMap);
             
        if(!orderList.isEmpty()){
            update orderList;
        }
    }
    
    public void afterDelete(){
        List<Order> orderList = OrderItemHelper.CalcTotalVolumeWeightQuantity(this.oldRecords);
        
        if(!orderList.isEmpty()){
            update orderList;
        }
    }
}
