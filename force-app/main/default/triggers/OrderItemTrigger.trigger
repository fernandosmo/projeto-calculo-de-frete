trigger OrderItemTrigger on OrderItem (after insert, before update, after delete) {

  OrderItemTriggerHandler handler = new OrderItemTriggerHandler(
    Trigger.old, Trigger.new, Trigger.oldMap, Trigger.newMap
  );

  switch on Trigger.operationType {
    when AFTER_INSERT {
      handler.afterInsert();
    }
    when BEFORE_UPDATE {
      handler.beforeUpdate();
    }
    when AFTER_DELETE {
      handler.afterDelete();
    }
  }
}