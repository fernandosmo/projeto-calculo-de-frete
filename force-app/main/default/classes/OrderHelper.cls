public with sharing class OrderHelper {
    public OrderHelper() {}
  
    //BLOQUEIA ALTERAÇÃO DO CLIENTE DO PEDIDO
    public static void blockChangeAccount(Map<Id, Order> oldRecords, Map<Id, Order> newRecords) {
        for (Order order : newRecords.values()) {
            Order oldRecord = oldRecords.get(order.Id);
  
            if (order.AccountId != oldRecord.AccountId) {
                order.addError(System.Label.BlockChangeAccount);
            }
        }
    }
    //BLOQUEIA ALTERAÇÕES EM PEDIDOS COM STATUS 'ACTIVATED'
    public static void blockOrderActivated(Map<Id, Order> oldRecords, Map<Id, Order> newRecords) {
        for (Order order : newRecords.values()) {
            Order oldRecord = oldRecords.get(order.id);
  
            if (oldRecord.Status == 'Activated') {
                order.addError(System.Label.blockOrderActivated);
            }
        }
    }
  }