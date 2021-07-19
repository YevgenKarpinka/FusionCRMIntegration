codeunit 50070 "Integration CRM"
{
    trigger OnRun()
    begin
        Execute();
    end;

    var
        ShipStationSetup: Record "ShipStation Setup";
        IntegrationCRMSetup: Record "Integration CRM Setup";
        EntityCRM: Record "Entity CRM";
        Item: Record Item;
        ItemDescr: Record "Item Description";
        Customers: Record Customer;
        SalesInvHeader: Record "Sales Invoice Header";
        BoxHeader: Record "Box Header";
        BoxLine: Record "Box Line";
        ItemUoM: Record "Item Unit of Measure";
        UoM: Record "Unit of Measure";
        CustomerMgt: Codeunit "Customer Mgt.";
        IntegrationCRMLog: Record "Integration CRM Log";
        PackageBoxMgt: Codeunit "Package Box Mgt.";
        requestMethodPOST: Label 'POST';
        requestURL: Text;
        requestBody: Text;
        Body: JsonObject;

    local procedure Execute()
    var
        tempEntityCRM: Record "Entity CRM";
    begin
        EntityCRM.Reset();
        if EntityCRM.IsEmpty then exit;

        EntityCRM.FindSet();
        repeat
            tempEntityCRM.SetRange(Code, EntityCRM.Code);
            if not tempEntityCRM.FindFirst() then begin
                tempEntityCRM := EntityCRM;
                tempEntityCRM.Insert();
            end;
        until EntityCRM.Next() = 0;

        tempEntityCRM.FindSet();
        repeat
            if OnPostEntity(tempEntityCRM.Code) then
                OnUpdateEntity(tempEntityCRM.Code);
        until tempEntityCRM.Next() = 0;
    end;

    local procedure OnUpdateEntity(entityType: Code[30])
    var
        locEntityCRM: Record "Entity CRM";
    begin
        locEntityCRM.SetRange(Code, entityType);
        locEntityCRM.ModifyAll("Modify In CRM", true, true);
    end;

    local procedure GetEntity(entityType: Code[30]; requestMethod: Code[10]; var requestBody: Text): Boolean
    var
        ContentType: Label 'Content-Type';
        ContentTypeValue: Label 'application/json';
        // EnvironmentType: Label 'Environment';
        // EnvironmentTypeValue: Label 'Production';
        Client: HttpClient;
        RequestMessage: HttpRequestMessage;
        responseBody: Text;
        ResponseMessage: HttpResponseMessage;
        RequestHeader: HttpHeaders;
        requestURL: Text;
    begin
        requestURL := GetURLForPostEntity(entityType);
        RequestMessage.Method := requestMethod;
        RequestMessage.SetRequestUri(requestURL);
        RequestMessage.GetHeaders(RequestHeader);
        case requestMethod of
            'POST', 'PATCH':
                begin
                    RequestMessage.Content.WriteFrom(requestBody);
                    RequestMessage.Content.GetHeaders(RequestHeader);
                    if RequestHeader.Contains(ContentType) then RequestHeader.Remove(ContentType);
                    RequestHeader.Add(ContentType, ContentTypeValue);
                    // to do split environment
                    // if not GetResourceProductionNotAllowed() then
                    //     RequestHeader.Add(EnvironmentType, EnvironmentTypeValue);
                end;
        end;

        Client.Send(RequestMessage, ResponseMessage);
        ResponseMessage.Content.ReadAs(responseBody);

        // Insert Operation to Log
        IntegrationCRMLog.InsertOperationToLog('CUSTOM_CRM_API', requestMethod, requestURL, '', requestBody, responseBody, ResponseMessage.IsSuccessStatusCode());

        exit(ResponseMessage.IsSuccessStatusCode);
    end;

    procedure OnPostEntity(entityType: Code[30]): Boolean
    begin
        // create requestBody
        case entityType of
            'PRODUCT':
                CreateRequestBodyForPostProduct(requestBody);
            'CLIENT':
                CreateRequestBodyForPostClient(requestBody);
            'INVOICE':
                CreateRequestBodyForPostInvoice(requestBody);
            'BOX':
                CreateRequestBodyForPostBox(requestBody);
            'BOXPRODUCTS':
                CreateRequestBodyForPostBoxProducts(requestBody);
            'PRIMARYUNITPRODUCT':
                CreateRequestBodyForPostPrimaryUnitProduct(requestBody);
            'UOM':
                CreateRequestBodyForPostUom(requestBody);
        end;

        // send to CRM
        exit(GetEntity(entityType, requestMethodPOST, requestBody));
    end;

    local procedure GetURLForPostEntity(entityType: Code[30]): Text
    begin
        if IntegrationCRMSetup.Get(entityType) then begin
            exit(StrSubstNo(IntegrationCRMSetup.URL, IntegrationCRMSetup.Param));
        end;
    end;

    local procedure CreateRequestBodyForPostProduct(requestBody: Text)
    var
        bodyArray: JsonArray;
    begin
        Clear(Body);
        Clear(requestBody);
        Item.Reset();
        EntityCRM.Reset();
        EntityCRM.SetRange(Code, 'PRODUCT');
        if EntityCRM.IsEmpty then exit;

        EntityCRM.FindSet();
        repeat
            UoM.SetRange(Code, EntityCRM.Key1);
            if Item.FindSet() then begin
                Clear(Body);
                if ItemDescr.Get(Item."No.") then;

                Body.Add('new_bc_product_number', Item."No.");
                Body.Add('name', ItemDescr."Name ENG");
                Body.Add('new_name_eng_2', ItemDescr."Name ENG 2");
                Body.Add('new_name_ru', ItemDescr."Name RU");
                Body.Add('new_name_ru_2', ItemDescr."Name RU 2");
                Body.Add('new_description_ru', Blob2TextFromRec(Database::"Item Description", ItemDescr.FieldNo("Description RU")));
                Body.Add('new_ingredients_ru', Blob2TextFromRec(Database::"Item Description", ItemDescr.FieldNo("Ingredients RU")));
                Body.Add('new_indications_ru', Blob2TextFromRec(Database::"Item Description", ItemDescr.FieldNo("Indications RU")));
                Body.Add('new_directions_ru', Blob2TextFromRec(Database::"Item Description", ItemDescr.FieldNo("Directions RU")));
                Body.Add('new_warning', Blob2TextFromRec(Database::"Item Description", ItemDescr.FieldNo(Warning)));
                Body.Add('new_legaldisclaimer', Blob2TextFromRec(Database::"Item Description", ItemDescr.FieldNo("Legal Disclaimer")));
                Body.Add('description', Blob2TextFromRec(Database::"Item Description", ItemDescr.FieldNo(Description)));
                Body.Add('new_ingredients', Blob2TextFromRec(Database::"Item Description", ItemDescr.FieldNo(Ingredients)));
                Body.Add('new_indications', Blob2TextFromRec(Database::"Item Description", ItemDescr.FieldNo(Indications)));
                Body.Add('new_directions', Blob2TextFromRec(Database::"Item Description", ItemDescr.FieldNo(Directions)));
                Body.Add('new_price', Item."Unit Price");

                bodyArray.Add(Body);
            end;
        until EntityCRM.Next() = 0;

        bodyArray.WriteTo(requestBody);
    end;

    local procedure CreateRequestBodyForPostClient(var requestBody: Text)
    var
        bodyArray: JsonArray;
    begin
        Clear(requestBody);
        EntityCRM.Reset();
        EntityCRM.SetRange(Code, 'CLIENT');
        if EntityCRM.IsEmpty then exit;

        EntityCRM.FindSet();
        repeat
            Customers.Get(EntityCRM.Key1);
            Customers.CalcFields(Balance, "Balance Due");
            Clear(Body);

            Body.Add('bcid', Customers."No.");
            Body.Add('name', Customers.Name + Customers."Name 2");
            Body.Add('balance', Customers.Balance);
            Body.Add('balanceDue', Customers."Balance Due");
            Body.Add('creditLimit', Customers."Credit Limit (LCY)");
            Body.Add('totalSales', CustomerGetTotalSales(Customers."No."));
            Body.Add('address', Customers.Address + Customers."Address 2");
            Body.Add('country', Customers."Country/Region Code");
            Body.Add('city', Customers.City);
            Body.Add('state', Customers.County);
            Body.Add('zipCode', Customers."Post Code");
            Body.Add('contactName', Customers.Contact);
            Body.Add('telephone', Customers."Phone No.");
            Body.Add('mobilePhone', Customers."Mobile Phone No.");
            Body.Add('emailAddress', Customers."E-Mail");
            Body.Add('faxNo', Customers."Fax No.");

            bodyArray.Add(Body);
        until EntityCRM.Next() = 0;

        bodyArray.WriteTo(requestBody);
    end;

    local procedure CustomerGetTotalSales(CustNo: Code[20]): Decimal
    var
        NoPostedInvoices: Integer;
        NoPostedCrMemos: Integer;
        NoOutstandingInvoices: Integer;
        NoOutstandingCrMemos: Integer;
        AmountOnPostedInvoices: Decimal;
        AmountOnPostedCrMemos: Decimal;
        AmountOnOutstandingInvoices: Decimal;
        AmountOnOutstandingCrMemos: Decimal;
        Totals: Decimal;
    begin
        NoPostedInvoices := 0;
        NoPostedCrMemos := 0;
        NoOutstandingInvoices := 0;
        NoOutstandingCrMemos := 0;
        Totals := 0;

        AmountOnPostedInvoices := CustomerMgt.CalcAmountsOnPostedInvoices(CustNo, NoPostedInvoices);
        AmountOnPostedCrMemos := CustomerMgt.CalcAmountsOnPostedCrMemos(CustNo, NoPostedCrMemos);
        AmountOnOutstandingInvoices := CustomerMgt.CalculateAmountsOnUnpostedInvoices(CustNo, NoOutstandingInvoices);
        AmountOnOutstandingCrMemos := CustomerMgt.CalculateAmountsOnUnpostedCrMemos(CustNo, NoOutstandingCrMemos);

        Totals := AmountOnPostedInvoices + AmountOnPostedCrMemos + AmountOnOutstandingInvoices + AmountOnOutstandingCrMemos;
        exit(Totals)
    end;

    local procedure CreateRequestBodyForPostInvoice(requestBody: Text)
    var
        bodyArray: JsonArray;
    begin
        Clear(requestBody);
        EntityCRM.Reset();
        EntityCRM.SetRange(Code, 'INVOICE');
        if EntityCRM.IsEmpty then exit;

        EntityCRM.FindSet();
        repeat
            SalesInvHeader.Get(EntityCRM.Key1);
            Clear(Body);

            Body.Add('bcid', SalesInvHeader.SystemId);
            Body.Add('invoiceNumber', SalesInvHeader."No.");
            Body.Add('customerId', SalesInvHeader."Sell-to Customer No.");
            Body.Add('address', SalesInvHeader."Sell-to Address" + SalesInvHeader."Sell-to Address 2");
            Body.Add('country', SalesInvHeader."Sell-to Country/Region Code");
            Body.Add('city', SalesInvHeader."Sell-to City");
            Body.Add('stateRegion', SalesInvHeader."Sell-to County");
            Body.Add('zipCode', SalesInvHeader."Sell-to Post Code");
            Body.Add('telephone', SalesInvHeader."Sell-to Phone No.");
            Body.Add('mobilePhone', SalesInvHeader."Sell-to Phone No.");
            Body.Add('emailAddress', SalesInvHeader."Sell-to E-Mail");
            Body.Add('dateDelivered', SalesInvHeader."Posting Date");
            Body.Add('dueDate', SalesInvHeader."Due Date");
            Body.Add('salesOrderId', SalesInvHeader."Order No.");
            Body.Add('transactionCurrencyId', SalesInvHeader."Currency Code");
            Body.Add('shipmentDate', SalesInvHeader."Shipment Date");

            bodyArray.Add(Body);
        until EntityCRM.Next() = 0;

        bodyArray.WriteTo(requestBody);
    end;

    local procedure CreateRequestBodyForPostBox(requestBody: Text)
    var
        bodyArray: JsonArray;
    begin
        Clear(requestBody);
        BoxHeader.Reset();
        EntityCRM.Reset();
        EntityCRM.SetRange(Code, 'BOX');
        if EntityCRM.IsEmpty then exit;

        EntityCRM.FindSet();
        repeat
            BoxHeader.SetRange("No.", EntityCRM.Key1);
            if BoxHeader.FindFirst() then begin
                Clear(Body);

                Body.Add('bcid', BoxHeader."Package No.");
                Body.Add('boxNumber', BoxHeader."No.");
                Body.Add('salesOrderId', BoxHeader."Sales Order No.");
                Body.Add('createdOn', BoxHeader."Create Date");
                Body.Add('statusCode', Format(BoxHeader.Status));
                Body.Add('externalDocumentNo', BoxHeader."External Document No.");
                Body.Add('boxCode', BoxHeader."Box Code");
                Body.Add('grossWeight', BoxHeader."Gross Weight");
                Body.Add('primaryUnitProductId', Format(BoxHeader."Unit of Measure"));
                Body.Add('quantity', PackageBoxMgt.GetQuantityInBox(BoxHeader."No."));
                Body.Add('trackingNo', BoxHeader."Tracking No.");
                Body.Add('shippingAgentId', BoxHeader."Shipping Agent Code");
                Body.Add('shippingAgentServiceId', BoxHeader."Shipping Services Code");
                Body.Add('shipStationStatusCode', BoxHeader."ShipStation Status");
                Body.Add('shipStationShipmentId', BoxHeader."ShipStation Shipment ID");
                Body.Add('shipStationOrderId', BoxHeader."ShipStation Order ID");
                Body.Add('shipStationOrderKey', BoxHeader."ShipStation Order Key");

                bodyArray.Add(Body);
            end;
        until EntityCRM.Next() = 0;

        bodyArray.WriteTo(requestBody);
    end;

    local procedure CreateRequestBodyForPostBoxProducts(requestBody: Text)
    var
        bodyArray: JsonArray;
    begin
        Clear(Body);
        Clear(requestBody);
        BoxLine.Reset();
        EntityCRM.Reset();
        EntityCRM.SetRange(Code, 'BOXPRODUCTS');
        if EntityCRM.IsEmpty then exit;

        EntityCRM.FindSet();
        repeat
            BoxLine.SetRange("Box No.", EntityCRM.Key1);
            if BoxLine.FindSet() then begin
                repeat
                    Clear(Body);

                    Body.Add('bcid', BoxLine."Line No.");
                    Body.Add('boxId', BoxLine."Box No.");
                    Body.Add('productId', BoxLine."Item No.");
                    Body.Add('quantity', BoxLine."Quantity in Box");

                    bodyArray.Add(Body);
                until BoxLine.Next() = 0;
            end;
        until EntityCRM.Next() = 0;

        bodyArray.WriteTo(requestBody);
    end;

    local procedure CreateRequestBodyForPostPrimaryUnitProduct(requestBody: Text)
    var
        bodyArray: JsonArray;
    begin
        Clear(Body);
        Clear(requestBody);
        ItemUoM.Reset();
        EntityCRM.Reset();
        EntityCRM.SetRange(Code, 'UOM');
        if EntityCRM.IsEmpty then exit;

        EntityCRM.FindSet();
        repeat
            ItemUoM.SetRange(Code, EntityCRM.Key1);
            if ItemUoM.FindSet() then begin
                Clear(Body);
                if Item.Get(ItemUoM."Item No.") then;

                Body.Add('bcid', ItemUoM.SystemId);
                Body.Add('productId', ItemUoM."Item No.");
                Body.Add('uomId', ItemUoM.Code);
                Body.Add('quantity', ItemUoM."Qty. per Unit of Measure");
                // added from price item uom
                // Body.Add('new_price', Item."Unit Price");

                bodyArray.Add(Body);
            end;
        until EntityCRM.Next() = 0;

        bodyArray.WriteTo(requestBody);
    end;

    local procedure CreateRequestBodyForPostUom(requestBody: Text)
    var
        bodyArray: JsonArray;
    begin
        Clear(Body);
        Clear(requestBody);
        UoM.Reset();
        EntityCRM.Reset();
        EntityCRM.SetRange(Code, 'UOM');
        if EntityCRM.IsEmpty then exit;

        EntityCRM.FindSet();
        repeat
            UoM.SetRange(Code, EntityCRM.Key1);
            if UoM.FindSet() then begin
                Clear(Body);

                Body.Add('bcid', UoM.SystemId);
                Body.Add('name', UoM.Code);
                Body.Add('description', UoM.Description);

                bodyArray.Add(Body);
            end;
        until EntityCRM.Next() = 0;

        bodyArray.WriteTo(requestBody);
    end;

    [EventSubscriber(ObjectType::Table, 18, 'OnAfterInsertEvent', '', false, false)]
    local procedure CustomerOnAfterInsertEvent(var Rec: Record Customer)
    begin
        // check enable integration CRM
        if CheckEnableIntegrationCRM() then
            EntityCRMOnUpdateIdBeforeSend('CLIENT', Rec."No.", '');
    end;

    [EventSubscriber(ObjectType::Table, 18, 'OnAfterModifyEvent', '', false, false)]
    local procedure CustomerOnAfterModifyEvent(var Rec: Record Customer)
    begin
        // check enable integration CRM
        if CheckEnableIntegrationCRM() then
            EntityCRMOnUpdateIdBeforeSend('CLIENT', Rec."No.", '');
    end;

    [EventSubscriber(ObjectType::Table, 27, 'OnAfterInsertEvent', '', false, false)]
    local procedure ItemOnAfterInsertEvent(var Rec: Record Item)
    begin
        // check enable integration CRM
        if CheckEnableIntegrationCRM() then
            EntityCRMOnUpdateIdBeforeSend('PRODUCT', Rec."No.", '');
    end;

    [EventSubscriber(ObjectType::Table, 27, 'OnAfterModifyEvent', '', false, false)]
    local procedure ItemOnAfterModifyEvent(var Rec: Record Item)
    begin
        // check enable integration CRM
        if CheckEnableIntegrationCRM() then begin
            EntityCRMOnUpdateIdBeforeSend('PRODUCT', Rec."No.", '');
        end;
    end;

    local procedure InsertEntityCRM(entityType: Text[30]; Key1: Code[20]; Key2: Code[20])
    var
        locEntityCRM: Record "Entity CRM";
    begin
        if locEntityCRM.Get(entityType, Key1, Key2) then exit;

        locEntityCRM.Init();
        locEntityCRM.Code := entityType;
        locEntityCRM.Key1 := Key1;
        locEntityCRM.Key2 := Key2;
        locEntityCRM.Insert(true);
    end;

    local procedure EntityCRMOnUpdateIdAfterSend(entityType: Text[30]; Key1: Code[20]; Key2: Code[20]; idCRM: Guid)
    var
        locEntityCRM: Record "Entity CRM";
    begin
        locEntityCRM.Get(entityType, Key1, Key2);
        if IsNullGuid(locEntityCRM."Id CRM") then
            locEntityCRM."Id CRM" := idCRM;
        locEntityCRM.Modify(true);
    end;

    local procedure EntityCRMOnUpdateIdBeforeSend(entityType: Text[30]; Key1: Code[20]; Key2: Code[20])
    var
        locEntityCRM: Record "Entity CRM";
    begin
        if not locEntityCRM.Get(entityType, Key1, Key2) then begin
            InsertEntityCRM(entityType, Key1, '');
            exit;
        end;

        locEntityCRM."Modify In CRM" := false;
        locEntityCRM.Modify(true);
    end;

    local procedure CheckEnableIntegrationCRM(): Boolean
    begin
        if not ShipStationSetup.Get() then begin
            ShipStationSetup.Init();
            ShipStationSetup.Insert();
        end;

        exit(ShipStationSetup."CRM Integration Enable");
    end;

    procedure Blob2TextFromRec(_TableId: Integer; _FieldNo: Integer): Text;
    var
        tmpTenantMedia: Record "Tenant Media" temporary;
        _FieldRef: FieldRef;
        _RecordRef: RecordRef;
        _InStream: InStream;
        TypeHelper: Codeunit "Type Helper";
        CR: Text[1];
    begin
        _RecordRef.Open(_TableId);
        _FieldRef := _RecordRef.Field(_FieldNo);
        _FieldRef.CalcField();
        tmpTenantMedia.Content := _FieldRef.Value;
        if tmpTenantMedia.Content.HasValue then begin
            CR[1] := 10;
            tmpTenantMedia.Content.CreateInStream(_InStream, TextEncoding::UTF8);
            exit(TypeHelper.ReadAsTextWithSeparator(_InStream, CR));
        end;

        exit('');
    end;
}