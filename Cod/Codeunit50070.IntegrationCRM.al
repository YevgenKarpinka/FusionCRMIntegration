codeunit 50070 "Integration CRM"
{
    trigger OnRun()
    begin
        Execute();
    end;

    var
        Window: Dialog;
        ShipStationSetup: Record "ShipStation Setup";
        IntegrationCRMSetup: Record "Integration CRM Setup";
        EntityCRM: Record "Entity CRM";
        Item: Record Item;
        ItemDescr: Record "Item Description";
        Customer: Record Customer;
        SalesInvHeader: Record "Sales Invoice Header";
        PackageHeader: Record "Package Header";
        BoxHeader: Record "Box Header";
        BoxLine: Record "Box Line";
        ItemUoM: Record "Item Unit of Measure";
        UoM: Record "Unit of Measure";
        CustomerMgt: Codeunit "Customer Mgt.";
        IntegrationCRMLog: Record "Integration CRM Log";
        PackageBoxMgt: Codeunit "Package Box Mgt.";
        requestMethodPOST: Label 'POST';
        requestURL: Text;
        Body: JsonObject;
        lblUoM: Label 'UOM';
        lblItem: Label 'ITEM';
        lblCustomer: Label 'CUSTOMER';
        lblInvoice: Label 'INVOICE';
        lblPackage: Label 'PACKAGE';
        lblSubStrURL: Label '%1%2';
        txtDialog: TextConst ENU = 'Create Request By %1\', RUS = 'Create Request By %1\';
        txtProgressBar: TextConst ENU = 'Rec No #2 From #3', RUS = 'Rec No #2 From #3';
        Recs: Integer;
        RecNo: Integer;
        blankGuid: Guid;



    local procedure Execute()
    var
        EntitySetup: Record "Entity Setup";
    begin
        EntityCRM.Reset();
        EntityCRM.SetCurrentKey(Code, "Modify In CRM");
        EntityCRM.SetRange("Modify In CRM", false);
        if EntityCRM.IsEmpty then exit;

        if EntitySetup.FindSet() then
            repeat
                EntityCRM.SetRange(Code, EntitySetup.Code);
                EntityCRM.SetRange("Modify In CRM", false);
                if EntityCRM.FindSet() then
                    OnPostEntity(EntitySetup.Code);
            until EntitySetup.Next() = 0;
    end;

    local procedure OnUpdateEntityByType(entityType: Code[30]; _Modified: Boolean)
    var
        locEntityCRM: Record "Entity CRM";
    begin
        if entityType <> '' then
            locEntityCRM.SetRange(Code, entityType);
        locEntityCRM.ModifyAll("Modify In CRM", _Modified, true);
    end;

    local procedure GetEntity(entityType: Code[30]; requestMethod: Code[10]; var requestBody: Text; var responseBody: Text): Boolean
    var
        ContentType: Label 'Content-Type';
        ContentTypeValue: Label 'application/json';
        // EnvironmentType: Label 'Environment';
        // EnvironmentTypeValue: Label 'Production';
        Client: HttpClient;
        RequestMessage: HttpRequestMessage;
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
        IntegrationCRMLog.InsertOperationToLog('CUSTOM_CRM_API', requestMethod, requestURL, '', requestBody, responseBody);

        exit(ResponseMessage.IsSuccessStatusCode);
    end;

    procedure OnPostEntity(entityType: Code[30]): Boolean
    var
        requestBody: Text;
        responseBody: Text;
    begin
        repeat
            // create requestBody
            case entityType of
                lblUoM:
                    CreateRequestBodyForPostUoms(requestBody);
                lblItem:
                    CreateRequestBodyForPostItems(requestBody);
                lblCustomer:
                    CreateRequestBodyForPostCustomer(requestBody);
                lblInvoice:
                    CreateRequestBodyForPostInvoice(requestBody);
                lblPackage:
                    CreateRequestBodyForPostPackage(requestBody);
            end;

            // while testing
            // if true then begin
            // SaveStreamToFile(requestBody, 'requestBody.txt');
            // exit;
            // end else begin
            GetEntity(entityType, requestMethodPOST, requestBody, responseBody);
            UpdateEntityIDAndStatus(entityType, responseBody);
        // end;
        until EntityCRM.IsEmpty;

        exit(false);
    end;

    local procedure UpdateEntityIDAndStatus(entityType: Code[30]; responseBody: Text);
    var
        isError: Boolean;
        Key1: Code[20];
        idCRM: Guid;
        idBC: Guid;
        jaEntity: JsonArray;
        jtEntity: JsonToken;
    begin
        jaEntity.ReadFrom(responseBody);
        foreach jtEntity in jaEntity do begin
            isError := GetJSToken(jtEntity.AsObject(), 'error').AsValue().AsBoolean();
            if not isError then begin
                Key1 := GetJSToken(jtEntity.AsObject(), 'bcNumber').AsValue().AsText();
                idCRM := GetJSToken(jtEntity.AsObject(), 'crmId').AsValue().AsText();
                idBC := GetJSToken(jtEntity.AsObject(), 'bcId').AsValue().AsText();
                EntityCRMOnUpdateIdAfterSend(entityType, Key1, '', idCRM);
            end;
        end;
    end;

    local procedure GetURLForPostEntity(entityType: Code[30]): Text
    begin
        if IntegrationCRMSetup.Get(entityType) then begin
            exit(StrSubstNo(lblSubStrURL, IntegrationCRMSetup.URL, IntegrationCRMSetup.Param));
        end;
    end;

    local procedure CreateRequestBodyForPostUoms(var requestBody: Text)
    var
        bodyArray: JsonArray;
    begin
        Clear(Body);
        Clear(requestBody);
        RecNo := 0;
        Recs := EntityCRM.Count;

        EntityCRM.FindSet();

        if GuiAllowed then begin
            Window.Open(StrSubstNo(txtDialog, UoM.TableCaption) + txtProgressBar);
            Window.Update(3, Recs);
        end;

        repeat
            RecNo += 1;
            if UoM.Get(EntityCRM.Key1) then begin
                Clear(Body);

                Body.Add('bcid', Format(UoM.SystemId, 36, 4));
                Body.Add('name', UoM.Code);
                Body.Add('description', UoM.Description);

                bodyArray.Add(Body);

                if GuiAllowed then
                    Window.Update(2, RecNo);
            end;
        until EntityCRM.Next() = 0;

        if GuiAllowed then
            Window.Close();

        bodyArray.WriteTo(requestBody);
    end;

    local procedure CreateRequestBodyForPostItems(var requestBody: Text)
    var
        bodyArray: JsonArray;
    begin
        Clear(Body);
        Clear(requestBody);
        RecNo := 0;
        Recs := EntityCRM.Count;

        EntityCRM.FindSet();

        if GuiAllowed then begin
            Window.Open(StrSubstNo(txtDialog, Item.TableCaption) + txtProgressBar);
            Window.Update(3, Recs);
        end;

        repeat
            RecNo += 1;
            if Item.Get(EntityCRM.Key1) then begin
                Clear(Body);

                Body.Add('bcid', Format(Item.SystemId, 36, 4));
                Body.Add('item_number', Item."No.");
                if ItemDescr.Get(Item."No.") then begin
                    Body.Add('name_eng', ItemDescr."Name ENG");
                    Body.Add('name_eng_2', ItemDescr."Name ENG 2");
                    Body.Add('name_ru', ItemDescr."Name RU");
                    Body.Add('name_ru_2', ItemDescr."Name RU 2");
                    Body.Add('description_ru', Blob2TextFromRec(Database::"Item Description", ItemDescr.RecordId, ItemDescr.FieldNo("Description RU")));
                    Body.Add('ingredients_ru', Blob2TextFromRec(Database::"Item Description", ItemDescr.RecordId, ItemDescr.FieldNo("Ingredients RU")));
                    Body.Add('indications_ru', Blob2TextFromRec(Database::"Item Description", ItemDescr.RecordId, ItemDescr.FieldNo("Indications RU")));
                    Body.Add('directions_ru', Blob2TextFromRec(Database::"Item Description", ItemDescr.RecordId, ItemDescr.FieldNo("Directions RU")));
                    Body.Add('warning', Blob2TextFromRec(Database::"Item Description", ItemDescr.RecordId, ItemDescr.FieldNo(Warning)));
                    Body.Add('legal_disclaimer', Blob2TextFromRec(Database::"Item Description", ItemDescr.RecordId, ItemDescr.FieldNo("Legal Disclaimer")));
                    Body.Add('description', Blob2TextFromRec(Database::"Item Description", ItemDescr.RecordId, ItemDescr.FieldNo(Description)));
                    Body.Add('ingredients', Blob2TextFromRec(Database::"Item Description", ItemDescr.RecordId, ItemDescr.FieldNo(Ingredients)));
                    Body.Add('indications', Blob2TextFromRec(Database::"Item Description", ItemDescr.RecordId, ItemDescr.FieldNo(Indications)));
                    Body.Add('directions', Blob2TextFromRec(Database::"Item Description", ItemDescr.RecordId, ItemDescr.FieldNo(Directions)));
                end;
                Body.Add('price', Item."Unit Price");
                Body.Add('baseuom', Format(GetUoMIdByCode(Item."Base Unit of Measure"), 36, 4));
                Body.Add('promotional_price', GetPromotionalPrice(Item."No."));
                Body.Add('productuom', GetItemUoM(Item."No."));

                bodyArray.Add(Body);

                if GuiAllowed then
                    Window.Update(2, RecNo);
            end;

            if RecNo < 100 then
                EntityCRM.Next();

            if (RecNo = 100) then
                EntityCRM.SetFilter(Key1, '%1..', EntityCRM.Key1)
            else
                if (Recs = RecNo) then
                    EntityCRM.SetFilter(Key1, '%1..', IncStr(EntityCRM.Key1));

        until (RecNo = 100) or (Recs = RecNo);

        if GuiAllowed then
            Window.Close();

        bodyArray.WriteTo(requestBody);
    end;

    local procedure GetUoMIdByCode(UoMCode: Code[10]): Guid
    var
        locUoM: Record "Unit of Measure";
    begin
        if locUoM.Get(UoMCode) then
            exit(locUoM.SystemId);

        exit('');
    end;

    local procedure GetPromotionalPrice(ItemNo: Code[20]): Boolean
    var
        locItemDescr: Record "Item Description";
    begin
        if locItemDescr.Get(ItemNo) then
            exit(locItemDescr."Sell-out" >= DT2Date(CurrentDateTime));
        exit(false);
    end;

    local procedure GetItemUoM(ItemNo: Code[20]): JsonArray
    var
        locItemUoM: Record "Item Unit of Measure";
        locUoM: Record "Unit of Measure";
        locJsonObject: JsonObject;
        locJsonArray: JsonArray;
    begin
        locItemUoM.SetRange("Item No.", ItemNo);
        if locItemUoM.FindSet() then
            repeat
                Clear(locJsonObject);
                locUoM.Get(locItemUoM.Code);

                locJsonObject.Add('uom_id', Format(GetUoMIdByCode(locUoM.Code), 36, 4));
                locJsonObject.Add('bcid', Format(locItemUoM.SystemId, 36, 4));
                locJsonObject.Add('qty_per_unit_of_measure', locItemUoM."Qty. per Unit of Measure");
                locJsonObject.Add('unit_price', GetUnitPriceByItemUoM(ItemNo, locItemUoM."Qty. per Unit of Measure"));
                locJsonObject.Add('promotional_price', GetPromotionalPrice(ItemNo));

                locJsonArray.Add(locJsonObject);
            until locItemUoM.Next() = 0;
        exit(locJsonArray);
    end;

    local procedure GetUnitPriceByItemUoM(ItemNo: Code[20]; ItemQtyPerUoM: Decimal): Decimal
    var
        loItem: Record Item;
    begin
        if loItem.Get(ItemNo) then
            exit(loItem."Unit Price" * ItemQtyPerUoM);
    end;

    local procedure CreateRequestBodyForPostCustomer(var requestBody: Text)
    var
        bodyArray: JsonArray;
    begin
        Clear(requestBody);
        RecNo := 0;
        Recs := EntityCRM.Count;

        EntityCRM.FindSet();

        if GuiAllowed then begin
            Window.Open(StrSubstNo(txtDialog, Customer.TableCaption) + txtProgressBar);
            Window.Update(3, Recs);
        end;

        repeat
            RecNo += 1;
            if Customer.Get(EntityCRM.Key1) then begin
                Customer.CalcFields(Balance, "Balance Due");
                Clear(Body);

                Body.Add('bcid', Format(Customer.SystemId, 36, 4));
                Body.Add('bc_number', Customer."No.");
                Body.Add('name', Customer.Name + Customer."Name 2");
                Body.Add('balance', Customer.Balance);
                Body.Add('balance_due', Customer."Balance Due");
                Body.Add('credit_limit', Customer."Credit Limit (LCY)");
                Body.Add('total_sales', CustomerGetTotalSales(Customer."No."));
                Body.Add('address', Customer.Address + Customer."Address 2");
                Body.Add('country', Customer."Country/Region Code");
                Body.Add('city', Customer.City);
                Body.Add('state', Customer.County);
                Body.Add('zip_code', Customer."Post Code");
                Body.Add('contact_name', Customer.Contact);
                Body.Add('telephone', Customer."Phone No.");
                Body.Add('mobile_phone', Customer."Mobile Phone No.");
                Body.Add('email_address', Customer."E-Mail");
                Body.Add('fax_no', Customer."Fax No.");

                bodyArray.Add(Body);
            end;

            if GuiAllowed then
                Window.Update(2, RecNo);

        until EntityCRM.Next() = 0;

        if GuiAllowed then
            Window.Close();

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

    local procedure CreateRequestBodyForPostInvoice(var requestBody: Text)
    var
        bodyArray: JsonArray;
    begin
        Clear(requestBody);
        RecNo := 0;
        Recs := EntityCRM.Count;

        EntityCRM.FindSet();

        if GuiAllowed then begin
            Window.Open(StrSubstNo(txtDialog, SalesInvHeader.TableCaption) + txtProgressBar);
            Window.Update(3, Recs);
        end;

        repeat
            RecNo += 1;
            if SalesInvHeader.Get(EntityCRM.Key1) then begin
                Clear(Body);

                Body.Add('bcid', Format(SalesInvHeader.SystemId, 36, 4));
                Body.Add('invoice_number', SalesInvHeader."No.");
                Body.Add('customer_id', SalesInvHeader."Sell-to Customer No.");
                Body.Add('date_delivered', Format(SalesInvHeader."Posting Date", 9));
                Body.Add('due_date', Format(SalesInvHeader."Due Date", 9));
                Body.Add('sales_order_no', SalesInvHeader."Order No.");
                Body.Add('currency_id', SalesInvHeader."Currency Code");
                Body.Add('shipment_date', Format(SalesInvHeader."Shipment Date", 9));
                Body.Add('invoice_detail', GetInvoiceLine(SalesInvHeader."No."));

                bodyArray.Add(Body);
            end;

            if GuiAllowed then
                Window.Update(2, RecNo);

        until EntityCRM.Next() = 0;

        if GuiAllowed then
            Window.Close();

        bodyArray.WriteTo(requestBody);
    end;

    local procedure GetInvoiceLine(InvoiceNo: Code[20]): JsonArray
    var
        locSIL: Record "Sales Invoice Line";
        locJsonObject: JsonObject;
        locJsonArray: JsonArray;
        boolTrue: Boolean;
    begin
        boolTrue := true;

        locSIL.SetRange("Document No.", InvoiceNo);
        locSIL.SetRange(Type, locSIL.Type::Item);
        locSIL.SetFilter(Quantity, '<>%1', 0);
        if locSIL.FindSet() then
            repeat
                Clear(locJsonObject);

                locJsonObject.Add('product', locSIL."No.");
                locJsonObject.Add('price', boolTrue);
                locJsonObject.Add('quantity', locSIL.Quantity);
                locJsonObject.Add('discount_amount', locSIL."Line Discount Amount");
                locJsonObject.Add('uom_id', Format(GetUoMIdByCode(locSIL."Unit of Measure Code"), 36, 4));
                locJsonObject.Add('price_perunit', locSIL."Unit Price");
                locJsonObject.Add('bcid', Format(locSIL.SystemId, 36, 4));

                locJsonArray.Add(locJsonObject);
            until locSIL.Next() = 0;

        exit(locJsonArray);
    end;

    local procedure CreateRequestBodyForPostPackage(var requestBody: Text)
    var
        bodyArray: JsonArray;
    begin
        Clear(requestBody);
        PackageHeader.Reset();
        EntityCRM.Reset();

        EntityCRM.SetRange(Code, lblPackage);
        if not EntityCRM.FindSet() then exit;
        repeat
            PackageHeader.SetRange("No.", EntityCRM.Key1);
            if PackageHeader.FindFirst() then begin
                Clear(Body);

                Body.Add('bcid', Format(PackageHeader.SystemId, 36, 4));
                Body.Add('package_number', PackageHeader."No.");
                Body.Add('sales_order_no', PackageHeader."Sales Order No.");
                Body.Add('create_on', Format(PackageHeader."Create Date", 9));
                Body.Add('status_code', Format(PackageHeader.Status));
                Body.Add('boxes', GetBoxesByPackage(PackageHeader."No."));

                bodyArray.Add(Body);
            end;
        until EntityCRM.Next() = 0;

        bodyArray.WriteTo(requestBody);
    end;

    local procedure GetBoxesByPackage(PackageNo: Code[20]): JsonArray
    var
        bodyArray: JsonArray;
    begin
        BoxHeader.Reset();

        BoxHeader.SetRange("Package No.", PackageNo);
        if not BoxHeader.FindSet() then exit;
        repeat
            Clear(Body);

            Body.Add('bcid', Format(BoxHeader.SystemId, 36, 4));
            Body.Add('box_number', BoxHeader."No.");
            Body.Add('create_on', Format(BoxHeader."Create Date", 9));
            Body.Add('status_code', Format(BoxHeader.Status));
            Body.Add('external_document_no', BoxHeader."External Document No.");
            Body.Add('box_code', BoxHeader."Box Code");
            Body.Add('gross_weight', BoxHeader."Gross Weight");
            Body.Add('uom_code', Format(BoxHeader."Unit of Measure"));
            Body.Add('tracking_no', BoxHeader."Tracking No.");
            Body.Add('shipping_agent_id', BoxHeader."Shipping Agent Code");
            Body.Add('shipping_agent_servise_id', BoxHeader."Shipping Services Code");
            Body.Add('shipstation_statuscode', BoxHeader."ShipStation Status");
            Body.Add('shipstation_shipment_id', BoxHeader."ShipStation Shipment ID");
            Body.Add('shipstation_order_id', BoxHeader."ShipStation Order ID");
            Body.Add('shipstation_order_key', BoxHeader."ShipStation Order Key");
            Body.Add('boxes_line', GetBoxesLineByBox(BoxHeader."No."));

            bodyArray.Add(Body);
        until BoxHeader.Next() = 0;

        exit(bodyArray);
    end;

    local procedure GetBoxesLineByBox(BoxNo: Code[20]): JsonArray
    var
        bodyArray: JsonArray;
    begin
        Clear(Body);
        BoxLine.Reset();

        BoxLine.SetRange("Box No.", BoxNo);
        if BoxLine.IsEmpty then exit;
        repeat
            Clear(Body);

            Body.Add('bcid', Format(BoxLine.SystemId, 36, 4));
            Body.Add('line_number', BoxLine."Line No.");
            Body.Add('item_number', BoxLine."Item No.");
            Body.Add('quantity', BoxLine."Quantity in Box");

            bodyArray.Add(Body);
        until BoxLine.Next() = 0;

        exit(bodyArray);
    end;

    [EventSubscriber(ObjectType::Table, 204, 'OnAfterInsertEvent', '', false, false)]
    local procedure UoMOnAfterInsertEvent(var Rec: Record "Unit of Measure")
    begin
        EntityCRMOnUpdateIdBeforeSend(lblUoM, Rec.Code, '', Rec.SystemId);
    end;

    [EventSubscriber(ObjectType::Table, 204, 'OnAfterModifyEvent', '', false, false)]
    local procedure UoMOnAfterModifyEvent(var Rec: Record "Unit of Measure")
    begin
        EntityCRMOnUpdateIdBeforeSend(lblUoM, Rec.Code, '', Rec.SystemId);
    end;

    [EventSubscriber(ObjectType::Table, 27, 'OnAfterInsertEvent', '', false, false)]
    local procedure ItemOnAfterInsertEvent(var Rec: Record Item)
    begin
        EntityCRMOnUpdateIdBeforeSend(lblItem, Rec."No.", '', Rec.SystemId);
    end;

    [EventSubscriber(ObjectType::Table, 27, 'OnAfterModifyEvent', '', false, false)]
    local procedure ItemOnAfterModifyEvent(var Rec: Record Item)
    begin
        EntityCRMOnUpdateIdBeforeSend(lblItem, Rec."No.", '', Rec.SystemId);
    end;

    [EventSubscriber(ObjectType::Table, 18, 'OnAfterInsertEvent', '', false, false)]
    local procedure CustomerOnAfterInsertEvent(var Rec: Record Customer)
    begin
        EntityCRMOnUpdateIdBeforeSend(lblCustomer, Rec."No.", '', Rec.SystemId);
    end;

    [EventSubscriber(ObjectType::Table, 18, 'OnAfterModifyEvent', '', false, false)]
    local procedure CustomerOnAfterModifyEvent(var Rec: Record Customer)
    begin
        EntityCRMOnUpdateIdBeforeSend(lblCustomer, Rec."No.", '', Rec.SystemId);
    end;

    [EventSubscriber(ObjectType::Table, 112, 'OnAfterInsertEvent', '', false, false)]
    local procedure SalesInvOnAfterInsertEvent(var Rec: Record "Sales Invoice Header")
    begin
        if not IsNullGuid(Rec."CRM ID") then
            EntityCRMOnUpdateIdBeforeSend(lblInvoice, Rec."No.", '', Rec.SystemId);
    end;

    [EventSubscriber(ObjectType::Table, 112, 'OnAfterModifyEvent', '', false, false)]
    local procedure SalesInvOnAfterModifyEvent(var Rec: Record "Sales Invoice Header")
    begin
        if not IsNullGuid(Rec."CRM ID") then
            EntityCRMOnUpdateIdBeforeSend(lblInvoice, Rec."No.", '', Rec.SystemId);
    end;

    [EventSubscriber(ObjectType::Codeunit, 50050, 'OnAfterRegisterPackage', '', false, false)]
    local procedure PackageOnAfterInsertEvent(PackageNo: Code[20])
    var
        locPackageHeader: Record "Package Header";
        locSIH: Record "Sales Invoice Header";
    begin
        if locPackageHeader.Get(PackageNo) then begin
            locSIH.SetCurrentKey("Order No.");
            locSIH.SetRange("Order No.", locPackageHeader."Sales Order No.");
            if locSIH.FindFirst() and not IsNullGuid(locSIH."CRM ID") then
                EntityCRMOnUpdateIdBeforeSend(lblPackage, PackageNo, '', locPackageHeader.SystemId);
        end;
    end;

    local procedure InsertEntityCRM(entityType: Text[30]; Key1: Code[20]; Key2: Code[20]; IdBC: Guid)
    var
        locEntityCRM: Record "Entity CRM";
    begin
        if not CheckEnableIntegrationCRM() then exit;

        if locEntityCRM.Get(entityType, Key1, Key2) then exit;

        locEntityCRM.Init();
        locEntityCRM.Code := entityType;
        locEntityCRM.Key1 := Key1;
        locEntityCRM.Key2 := Key2;
        locEntityCRM."Id BC" := IdBC;
        locEntityCRM.Insert(true);
    end;

    procedure EntityCRMOnUpdateIdBeforeSend(entityType: Text[30]; Key1: Code[20]; Key2: Code[20]; IdBC: Guid)
    var
        locEntityCRM: Record "Entity CRM";
    begin
        // check enable integration CRM
        if not CheckEnableIntegrationCRM() or (Key1 = '') then exit;

        if not locEntityCRM.Get(entityType, Key1, Key2) then begin
            InsertEntityCRM(entityType, Key1, Key2, IdBC);
            exit;
        end;

        locEntityCRM."Modify In CRM" := false;
        locEntityCRM.Modify(true);
    end;

    local procedure EntityCRMOnUpdateIdAfterSend(entityType: Text[30]; Key1: Code[20]; Key2: Code[20]; idCRM: Guid)
    var
        locEntityCRM: Record "Entity CRM";
    begin
        // check enable integration CRM
        if not CheckEnableIntegrationCRM() or (Key1 = '') then exit;

        locEntityCRM.Get(entityType, Key1, Key2);
        locEntityCRM."Id CRM" := idCRM;
        locEntityCRM."Modify In CRM" := true;
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

    procedure Blob2TextFromRec(_TableId: Integer; _RecirdId: RecordId; _FieldNo: Integer): Text;
    var
        tmpTenantMedia: Record "Tenant Media" temporary;
        _FieldRef: FieldRef;
        _RecordRef: RecordRef;
        _InStream: InStream;
        TypeHelper: Codeunit "Type Helper";
        CR: Text[1];
    begin
        _RecordRef.Open(_TableId);
        if _RecordRef.Get(_RecirdId) then begin
            _FieldRef := _RecordRef.Field(_FieldNo);
            _FieldRef.CalcField();
            tmpTenantMedia.Content := _FieldRef.Value;
            if tmpTenantMedia.Content.HasValue then begin
                CR[1] := 10;
                tmpTenantMedia.Content.CreateInStream(_InStream, TextEncoding::UTF8);
                exit(DelChr(TypeHelper.ReadAsTextWithSeparator(_InStream, CR), '=', '"'));
            end;
        end;

        exit('');
    end;

    procedure PostAllEntities()
    begin
        if not CheckEnableIntegrationCRM() then exit;

        PostAllUoM();
        PostAllItems();
        PostAllCustomers();
        PostAllInvoices();
        PostAllPackages();
        OnUpdateEntityByType('', false);
    end;

    local procedure PostAllUoM()
    var
        locEntityCRM: Record "Entity CRM";
    begin
        UoM.Reset();
        if UoM.FindSet() then
            repeat
                if not locEntityCRM.Get(lblUoM, UoM.Code, '') then
                    InsertEntityCRM(lblUoM, UoM.Code, '', UoM.SystemId);
            until UoM.Next() = 0;
    end;

    local procedure PostAllItems()
    var
        locEntityCRM: Record "Entity CRM";
    begin
        Item.Reset();
        if Item.FindSet() then
            repeat
                if not locEntityCRM.Get(lblItem, Item."No.", '') then
                    InsertEntityCRM(lblItem, Item."No.", '', Item.SystemId);
            until Item.Next() = 0;
    end;

    local procedure PostAllCustomers()
    var
        locEntityCRM: Record "Entity CRM";
    begin
        Customer.Reset();
        if Customer.FindSet() then
            repeat
                if not locEntityCRM.Get(lblCustomer, Customer."No.", '') then
                    InsertEntityCRM(lblCustomer, Customer."No.", '', Customer.SystemId);
            until Customer.Next() = 0;
    end;

    local procedure PostAllInvoices()
    var
        locEntityCRM: Record "Entity CRM";
    begin
        SalesInvHeader.Reset();
        SalesInvHeader.SetCurrentKey("CRM ID");
        SalesInvHeader.SetFilter("CRM ID", '<>%1', blankGuid);
        if SalesInvHeader.FindSet() then
            repeat
                if not locEntityCRM.Get(lblInvoice, SalesInvHeader."No.", '') then
                    InsertEntityCRM(lblInvoice, SalesInvHeader."No.", '', SalesInvHeader.SystemId);
            until SalesInvHeader.Next() = 0;
    end;

    local procedure PostAllPackages()
    var
        locEntityCRM: Record "Entity CRM";
    begin
        PackageHeader.Reset();
        if PackageHeader.FindSet() then
            repeat
                if SalesOrderFromCRM(PackageHeader."Sales Order No.")
                and not locEntityCRM.Get(lblPackage, PackageHeader."No.", '') then
                    InsertEntityCRM(lblPackage, PackageHeader."No.", '', PackageHeader.SystemId);
            until PackageHeader.Next() = 0;
    end;

    local procedure SalesOrderFromCRM(OrderNo: Code[20]): Boolean
    var
        locSH: Record "Sales Header";
        locSIH: Record "Sales Invoice Header";
    begin
        if locSH.Get(locSH."Document Type"::Order, OrderNo)
        and not IsNullGuid(locSH."CRM ID") then
            exit(true);

        locSIH.SetCurrentKey("Order No.");
        locSIH.SetRange("Order No.", OrderNo);
        if locSIH.FindFirst()
        and not IsNullGuid(locSIH."CRM ID") then
            exit(true);

        exit(false);
    end;

    procedure GetJSToken(_JSONObject: JsonObject; TokenKey: Text) _JSONToken: JsonToken
    begin
        if not _JSONObject.Get(TokenKey, _JSONToken) then
            Error('Could not find a token with key %1', TokenKey);
    end;

    local procedure SelectJSToken(_JSONObject: JsonObject; Path: Text) _JSONToken: JsonToken
    begin
        if not _JSONObject.SelectToken(Path, _JSONToken) then
            Error('Could not find a token with path %1', Path);
    end;

    procedure SaveStreamToFile(_streamText: Text; ToFileName: Variant)
    var
        tmpTenantMedia: Record "Tenant Media";
        _inStream: inStream;
        _outStream: outStream;
    begin
        tmpTenantMedia.Content.CreateOutStream(_OutStream, TextEncoding::UTF8);
        _outStream.WriteText(_streamText);
        tmpTenantMedia.Content.CreateInStream(_inStream, TextEncoding::UTF8);
        DownloadFromStream(_inStream, 'Export', '', 'All Files (*.*)|*.*', ToFileName);
    end;
}