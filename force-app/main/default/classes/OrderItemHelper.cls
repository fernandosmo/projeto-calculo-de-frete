public with sharing class OrderItemHelper {
    public OrderItemHelper() {}

    // ENCONTRA  PRODUTOS DE PEDIDOS QUE TIVERAM ALTERAÇÕES PARA QUE POSSAM SER CALCULADOS OS DEVIDOS FRETES
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

    /* RECEBE A LISTA DE PRODUTOS DO PEDIDO, CRIA UM SET DE PEDIDOS ALTERADOS, DEPOIS FAZ UM AGGREGATE RESULT PARA SOMAR OS TOTAIS DE QUANTIDADE, 
    VOLUME E PESO DOS PRODUTOS DESSES PEDIDOS. DEPOIS DISSO, INVOCA O METODO DE CALCULO DE FRETE PARA ESSES PEDIDOS*/
    public static List<Order> CalcTotalVolumeWeightQuantity(List<OrderItem> orderItemList) {

        Set<Id> orderIdSet = new Set<Id>();
        for(OrderItem orderItem : orderItemList){
            orderIdSet.add(orderItem.Id);
        }

        List<AggregateResult> orderItemTotals = getAggregatedValues(orderIdSet);

        List<Order> orderList = findingDcFreight(orderItemTotals);
        
        return orderList;
    }

    // FAZ AS SOMAS DOS TOTAIS DE QUANTIDADE, PESO E VOLUME POR PEDIDO
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

        /* LISTAS DE PEDIDOS, CONTAS, FRETES, CENTROS DE DISTRIBUIÇÕES 
        PARA FAZER O CALCULO DE FRETE ELIMINANDO AS INFORMAÇÕES DESNECESSÁRIAS */
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

        // MAPA ONDE FICARÁ OS PEDIDOS COM AS INFORMAÇÕES DE FRETE POVOADAS
        Map<Id, Order> orderMap = new Map<Id, Order>();

        // CAMINHA POR CADA AGGREGATERESULT COM AS SOMAS DE QUANTIDADE, PESO E VOLUME
        for (AggregateResult result : orderItemTotals) {
            
            Id orderId = (Id)result.get('OrderId');
            
            Decimal totalItems = (Decimal)result.get('totalItems');
            Decimal totalWeight = (Decimal)result.get('totalWeight');
            Decimal totalVolume = (Decimal)result.get('totalVolume');

            // COM CADA AGGREGATERESULT COMPARA O ORDERID COM O ID DE CADA ORDER PARA ENCONTRAR SUAS DEVIDAS INFORMAÇÕES
            for(Order order : orderList) {

                if(order.Id == orderId) {

                    /* MAPA ONDE SERÁ COLOCADO AS MELHORES OPÇÕES DE FRETE DE CADA CENTRO DE DISTRIBUIÇÃO 
                    PARA SER ESCOLHIDO O MELHOR FRETE PARA O PEDIDO */
                    Map<Id, Freight__c> freightListToChoose = new Map<Id, Freight__c>();

                    /* APÓS ENCONTRAR O PEDIDO, PROCURA NA LISTA DE CLIENTES O CLIENTE 
                    DO PEDIDO PARA TRAZER SUAS INFORMAÇÕES DE LOCALIDADE */
                    for(Account account : accountList) {

                        // VERIFICA SE O ID DO CLIENTE BATE COM O ID DO CLIENTE DO PEDIDO
                        if(account.Id == order.AccountId){
                            
                            /* APÓS ENCONTRAR O CLIENTE SERÁ PASSADO POR CADA CENTRO DE DISTRIBUIÇÃO 
                            PARA QUE SEJÁ ENCONTRADO OS FRETES QUE POSSAM ATENDER O PEDIDO */
                            for( DistributionCenter__c dc : dcList) {
                                
                                /* USANDO O ID DO CENTRO DE DISTRIBUIÇÃO DO LOOP, É GERADO UMA LISTA 
                                COM TODOS OS SEUS FRETES FILTRANDO A LISTA COM TODOS OS FRETES DISPONÍVEIS */
                                List<Freight__c> freightList = new List<Freight__c>();

                                for(Freight__c freight : freightListComplete) {
                                    if(freight.DistributionCenter__c == dc.Id){
                                        freightList.add(freight);
                                    }
                                }

                                /* OBJETO CRIADO COM INFORMAÇÃO DE FRETE BASE PARA AUXILIO NA PROCURA DO MELHOR FRETE E 
                                APÓS ENCONTRAR SERÁ SUBSTITUÍDO PELO FRETE QUE MELHOR ATENDE O PEDIDO PARA CADA CENTRO DE DISTRIBUIÇÃO */
                                Freight__c betterFreightDc = new Freight__c(FreightBase__c = 0);
                       
                                /* SE O VALOR DO FRETE BASE AINDA FOR 0, QUER DIZER QUE AINDA NÃO FOI ENCONTRADO O FRETE IDEAL
                                E, NESSE CASO, SERÁ VERIFICADOS OS FRETES QUE TENHAM O MESMO CEP DO CLIENTE DO PEDIDO, CASO ALGUM BATA, 
                                SERÁ ALTERADO O OBJETO DE FRETE QUE MELHOR ATENDE O PEDIDO NO CENTRO E ESSE FRETE SERÁ ADICIONADO NO
                                MAPA DE FRETES QUE COMPETIRÃO PARA VER QUAL SERÁ O ESCOLHIDO PARA O PEDIDO */
                                if(betterFreightDc.FreightBase__c == 0) {
                                    for(Freight__c freight : freightList) {
                                        if(freight.DistributionCenter__c == dc.Id && freight.CEP__c == account.CEP__c) {
                                            betterFreightDc = freight;
                                            freightListToChoose.put(betterFreightDc.Id, betterFreightDc);
                                        }
                                    }
                                }
                                /* SE O VALOR DO FRETE BASE AINDA FOR 0, QUER DIZER QUE AINDA NÃO FOI ENCONTRADO O FRETE IDEAL
                                E, NESSE CASO, SERÁ VERIFICADOS OS FRETES QUE TENHAM A MESMA CIDADE DO CLIENTE DO PEDIDO, CASO ALGUM BATA, 
                                SERÁ ALTERADO O OBJETO DE FRETE QUE MELHOR ATENDE O PEDIDO NO CENTRO E ESSE FRETE SERÁ ADICIONADO NO
                                MAPA DE FRETES QUE COMPETIRÃO PARA VER QUAL SERÁ O ESCOLHIDO PARA O PEDIDO */
                                if(betterFreightDc.FreightBase__c == 0) {
                                    for(Freight__c freight : freightList) {
                                        if(freight.DistributionCenter__c == dc.Id && freight.City__c == account.City__c) {
                                            betterFreightDc = freight;
                                            freightListToChoose.put(betterFreightDc.Id, betterFreightDc);       
                                        }
                                    }
                                }
                                /* SE O VALOR DO FRETE BASE AINDA FOR 0, QUER DIZER QUE AINDA NÃO FOI ENCONTRADO O FRETE IDEAL
                                E, NESSE CASO, SERÁ VERIFICADOS OS FRETES QUE TENHAM O MESMO ESTADO DO CLIENTE DO PEDIDO, CASO ALGUM BATA, 
                                SERÁ ALTERADO O OBJETO DE FRETE QUE MELHOR ATENDE O PEDIDO NO CENTRO E ESSE FRETE SERÁ ADICIONADO NO
                                MAPA DE FRETES QUE COMPETIRÃO PARA VER QUAL SERÁ O ESCOLHIDO PARA O PEDIDO */
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

                    // VARIAVEL QUE IRÁ RECEBER VALOR DO FRETE QUE ATENDERÁ O PEDIDO
                    Decimal freightValue = 999999999;

                    // OBJETO QUE RECEBERA O FRETE ESCOLHIDO
                    Freight__c freightChoosed = new Freight__c();

                    // LOOP COM AS OPÇÕES DE FRETE, QUE ATENDEM AS REGRAS ESTIPULADAS, POR CENTRO DE DISTRIBUIÇÃO
                    for (Freight__c freight : FreightListToChoose.values()) {
                        Decimal totalFreightByVolumeOrder = 0;
                        Decimal totalFreightByWeightOrder = 0;
                        Decimal totalFreightByQuantityOrder = 0; 

                        // CALCULO DE VALORES DE FRETE POR VOLUME, PESO E QUANTIDADE
                        if (freight.FreightByVolume__c != null && freight.FreightByWeight__c != null && freight.FreightBase__c != null) {
                            totalFreightByVolumeOrder = totalVolume * freight.FreightByVolume__c;
                            totalFreightByWeightOrder = totalWeight * freight.FreightByWeight__c;
                            totalFreightByQuantityOrder = totalItems * freight.FreightBase__c;
                        }

                        // VERIFICA SE O VALOR DE FRETE  POR VOLUME É O MAIOR DELES PARA ATENDER TODOS OS CUSTOS, SEGUINDO A REGRA EXIGIDA
                        if (totalFreightByVolumeOrder >= totalFreightByWeightOrder && totalFreightByVolumeOrder >= totalFreightByQuantityOrder) {

                            /* APÓS DECIDIR SE ESSE É O MAIOR VALOR DE FRETE POR TIPO DE FRETE, 
                            SERÁ VERIFICADO SE ESSE VALOR É O MENOR DETRE TODAS AS POSSIBILIDADES DE FRETE, SE SIM, 
                            ESSE SERÁ O FRETE ESCOLHIDO PARA O PEDIDO E SERÁ ATUALIZADO O VALOR DO FRETE*/
                            if (freightValue > totalFreightByVolumeOrder) {
                                freightValue = totalFreightByVolumeOrder;
                                FreightChoosed = freight;
                            }
                        } 
                        // VERIFICA SE O VALOR DE FRETE  POR VOLUME É O MAIOR DELES PARA ATENDER TODOS OS CUSTOS, SEGUINDO A REGRA EXIGIDA
                        else if (totalFreightByWeightOrder > totalFreightByVolumeOrder && totalFreightByWeightOrder >= totalFreightByQuantityOrder) {

                            /* APÓS DECIDIR SE ESSE É O MAIOR VALOR DE FRETE POR TIPO DE FRETE, 
                            SERÁ VERIFICADO SE ESSE VALOR É O MENOR DETRE TODAS AS POSSIBILIDADES DE FRETE, SE SIM, 
                            ESSE SERÁ O FRETE ESCOLHIDO PARA O PEDIDO E SERÁ ATUALIZADO O VALOR DO FRETE*/
                            if (freightValue > totalFreightByWeightOrder) {
                                freightValue = totalFreightByWeightOrder;
                                FreightChoosed = freight;
                            }
                        }
                        // VERIFICA SE O VALOR DE FRETE  POR VOLUME É O MAIOR DELES PARA ATENDER TODOS OS CUSTOS, SEGUINDO A REGRA EXIGIDA
                        else if (totalFreightByQuantityOrder > totalFreightByVolumeOrder && totalFreightByQuantityOrder > totalFreightByWeightOrder) {

                            /* APÓS DECIDIR SE ESSE É O MAIOR VALOR DE FRETE POR TIPO DE FRETE, 
                            SERÁ VERIFICADO SE ESSE VALOR É O MENOR DETRE TODAS AS POSSIBILIDADES DE FRETE, SE SIM, 
                            ESSE SERÁ O FRETE ESCOLHIDO PARA O PEDIDO E SERÁ ATUALIZADO O VALOR DO FRETE*/
                            if (freightValue > totalFreightByQuantityOrder) {
                                freightValue = totalFreightByQuantityOrder;
                                FreightChoosed = freight;
                            }
                        }
                    }

                    /* VERIFICA SE O FRETE ESCOLHIDO PARA O PEDIDO FOI PREENCHIDO, SE SIM, 
                    ATUALIZA AS INFORMAÇÕES DE FRETE E CENTRO DE DISTRIBUIÇÃO NO PEDIDO E TAMBÉM
                    VERIFICA SE O VALOR DO FRETE NÃO É MAIS O VALOR FICTÍCIO E ENTÃO ATUALIZA O VALOR DO FRETE NO PEDIDO*/
                    if(freightChoosed != null) {
                        if(freightValue != 999999999){
                            order.TotalFreight__c = freightValue;
                        }
                    
                        order.Freight__c = freightChoosed.Id;
                        order.DistributionCenter__c = freightChoosed.DistributionCenter__c;
                    }

                    // COM TODAS AS INFORMAÇÕES PREENCHIDAS NO PEDIDO, ADICIONA O MESMO NO MAPA DE PEDIDOS QUE SERÁ ATUALIZADO NO BANCO DE DADOS
                    orderMap.put(orderId, order);
                }
            }
        }

        // RETORNA OS VALORES DO MAPA DE PEDIDOS COM AS INFORMAÇÕES PRENCHIDAS
        return orderMap.values();
    }
}