public with sharing class OrderHelper {
    public OrderHelper() {}
  
    public static void blockChangeAccount(Map<Id, Order> oldRecords, Map<Id, Order> newRecords) {
        for (Order order : newRecords.values()) {
            Order oldRecord = oldRecords.get(order.Id);
  
            if (order.AccountId != oldRecord.AccountId) {
                order.addError(System.Label.BlockChangeAccount);
            }
        }
    }
    public static void blockOrderActivated(Map<Id, Order> oldRecords, Map<Id, Order> newRecords) {
        for (Order order : newRecords.values()) {
            Order oldRecord = oldRecords.get(order.id);
  
            if (oldRecord.Status == 'Activated') {
                order.addError(System.Label.blockOrderActivated);
            }
        }
    }
  }