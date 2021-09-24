codeunit 50070 "Integration CRM"
{
    trigger OnRun()
    begin
        CodeForEntity();
        // Send payment
        CodeForPayment();
    end;

    var
        SRSetup: Record "Sales & Receivables Setup";
        Window: Dialog;
        PackageBoxMgt: Codeunit "Package Box Mgt.";
        ShipStationSetup: Record "ShipStation Setup";
        IntegrationCRMSetup: Record "Integration CRM Setup";
        EntityCRM: Record "Entity CRM";
        Item: Record Item;
        ItemDescr: Record "Item Description";
        glBrand: Record Brand;
        glManufacturer: Record Manufacturer;
        Customer: Record Customer;
        SalesInvHeader: Record "Sales Invoice Header";
        PackageHeader: Record "Package Header";
        BoxHeader: Record "Box Header";
        BoxLine: Record "Box Line";
        UoM: Record "Unit of Measure";
        ItemCategory: Record "Item Category";
        ItemFilterGroup: Record "Item Filter Group";
        CustomerMgt: Codeunit "Customer Mgt.";
        IntegrationCRMLog: Record "Integration CRM Log";
        requestMethodPOST: Label 'POST';
        Body: JsonObject;
        lblUoM: Label 'UOM';
        lblItem: Label 'ITEM';
        lblCustomer: Label 'CUSTOMER';
        lblInvoice: Label 'INVOICE';
        lblPackage: Label 'PACKAGE';
        lblPayment: Label 'PAYMENT';
        lblOrderStatus: Label 'ORDERSTATUS';
        lblOrderSubmitted: TextConst ENU = 'Submitted', RUS = 'Передан';
        lblOrderInProgress: TextConst ENU = 'In Progress', RUS = 'В работе';
        lblOrderCompleted: TextConst ENU = 'Completed', RUS = 'Выполнен';
        lblOrderCancelled: TextConst ENU = 'Cancelled', RUS = 'Отменен';
        lblInvoiceStatus: Label 'INVOICESTATUS';
        lblInvoiceOpen: TextConst ENU = 'Open', RUS = 'Открытый';
        lblInvoicePaid: TextConst ENU = 'Paid', RUS = 'Оплачен';
        lblInvoiceOverdue: TextConst ENU = 'Overdue', RUS = 'Просрочен';
        lblUpdateOrder: Label 'UPDATEORDER';
        lblItemCategory: Label 'ITEMCATEGORY';
        lblSubStrURL: Label '%1%2';
        lblFileName: Label 'RequestBody_%1.txt';
        txtDialog: TextConst ENU = 'Create Request By %1\', RUS = 'Create Request By %1\';
        txtProgressBar: TextConst ENU = 'Send Records Count #2 Remaining Records #3', RUS = 'Send Records Count #2 Remaining Records #3';
        Recs: Integer;
        RecNo: Integer;
        blankGuid: Guid;
        boolTrue: Boolean;

    local procedure CodeForEntity()
    var
        EntitySetup: Record "Entity Setup";
    begin
        EntityCRM.Reset();
        EntityCRM.SetCurrentKey(Code, "Modify In CRM");
        EntityCRM.SetRange("Modify In CRM", false);
        if EntityCRM.IsEmpty then exit;

        EntitySetup.SetCurrentKey(Rank);
        if EntitySetup.FindSet() then
            repeat
                EntityCRM.Reset();
                EntityCRM.SetCurrentKey(Code, Rank, "Modify In CRM");
                EntityCRM.SetRange(Code, EntitySetup.Code);
                EntityCRM.SetRange("Modify In CRM", false);
                if EntityCRM.FindSet() then
                    OnPostEntity(EntitySetup.Code);
            until EntitySetup.Next() = 0;
    end;

    local procedure CodeForPayment()
    var
        PaymentCRM: Record "Payment CRM";
    begin
        PaymentCRM.Reset();
        PaymentCRM.SetCurrentKey(Apply, "Modify In CRM");
        PaymentCRM.SetAscending(Apply, false);
        PaymentCRM.SetRange("Modify In CRM", false);
        if PaymentCRM.FindSet() then
            // repeat
                OnPostPayment(PaymentCRM);
        // until PaymentCRM.Next() = 0;
    end;

    local procedure OnPostPayment(var PaymentCRM: Record "Payment CRM"): Boolean
    var
        requestBody: Text;
        responseBody: Text;
    begin
        repeat
            InitRequestBodyForPostPayment(PaymentCRM, requestBody);
            // create requestBody
            CreateRequestBodyForPostPayment(PaymentCRM, requestBody);

            if isSaveRequestBodyToFile(lblPayment) and GuiAllowed then begin
                // while testing
                SaveStreamToFile(requestBody, StrSubstNo(lblFileName, lblPayment));
                exit;
            end else begin
                if requestBody <> '[]' then
                    if GetEntity(lblPayment, requestMethodPOST, requestBody, responseBody) then
                        UpdatePaymentIdCRM(lblPayment, responseBody);
            end;
        until PaymentCRM.IsEmpty or (requestBody = '[]');

        if GuiAllowed then
            Window.Close();

        exit(true);
    end;

    local procedure UpdateEntityCRM(entityType: Code[30]; Key1Filter: Text; _Modified: Boolean)
    var
        locEntityCRM: Record "Entity CRM";
    begin
        if entityType <> '' then
            locEntityCRM.SetRange(Code, entityType);
        if Key1Filter <> '' then
            locEntityCRM.SetFilter(Key1, '%1', Key1Filter);
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
        if StrLen(DelChr(requestURL, '', ' ')) = 0 then exit(false);

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
            InitRequestBodyForPost(entityType, requestBody);
            // create requestBody
            case entityType of
                lblUoM:
                    CreateRequestBodyForPostUoms(requestBody);
                lblItemCategory:
                    CreateRequestBodyForPostItemCategory(requestBody);
                lblItem:
                    CreateRequestBodyForPostItems(requestBody);
                lblCustomer:
                    CreateRequestBodyForPostCustomer(requestBody);
                lblInvoice:
                    CreateRequestBodyForPostInvoice(requestBody);
                lblPackage:
                    CreateRequestBodyForPostPackage(requestBody);
                lblUpdateOrder:
                    CreateRequestBodyForPostUpdateOrder(requestBody);
                lblOrderStatus:
                    CreateRequestBodyForPostOrderStatus(requestBody);
                lblInvoiceStatus:
                    CreateRequestBodyForPostInvoiceStatus(requestBody);
            end;

            if isSaveRequestBodyToFile(entityType) and GuiAllowed then begin
                // while testing
                SaveStreamToFile(requestBody, StrSubstNo(lblFileName, entityType));
                exit(true);
            end else begin
                if GetEntity(entityType, requestMethodPOST, requestBody, responseBody) then
                    UpdateEntityIDAndStatus(entityType, responseBody);
            end;
        until EntityCRM.IsEmpty;

        if GuiAllowed then
            Window.Close();

        exit(true);
    end;

    local procedure InitRequestBodyForPost(entityType: Code[30]; var requestBody: Text)
    begin

        Clear(requestBody);
        RecNo := 0;
        Recs := EntityCRM.Count;

        EntityCRM.FindSet();

        if GuiAllowed then begin
            Window.Open(StrSubstNo(txtDialog, entityType) + txtProgressBar);
            Window.Update(3, Recs);
        end;
    end;

    local procedure InitRequestBodyForPostPayment(var PaymentCRM: Record "Payment CRM"; var requestBody: Text)
    begin
        Clear(requestBody);
        RecNo := 0;
        Recs := PaymentCRM.Count;

        PaymentCRM.FindSet();

        if GuiAllowed then begin
            Window.Open(StrSubstNo(txtDialog, lblPayment) + txtProgressBar);
            Window.Update(3, Recs);
        end;
    end;

    local procedure isSaveRequestBodyToFile(entityType: Code[30]): Boolean
    var
        locEntitySetup: Record "Entity Setup";
    begin
        locEntitySetup.Get(entityType);
        exit(locEntitySetup."Request To File");
    end;

    local procedure UpdatePaymentIdCRM(entityType: Code[30]; responseBody: Text);
    var
        isError: Boolean;
        PaymentNo: Code[20];
        InvoiceNo: Code[20];
        EntryApply: Boolean;
        idCRM: Guid;
        idBC: Guid;
        jaEntity: JsonArray;
        jtEntity: JsonToken;
    begin
        jaEntity.ReadFrom(responseBody);
        foreach jtEntity in jaEntity do begin
            isError := GetJSToken(jtEntity.AsObject(), 'error').AsValue().AsBoolean();
            if not isError then begin
                Clear(idCRM);
                PaymentNo := GetJSToken(jtEntity.AsObject(), 'bcNumber').AsValue().AsText();
                InvoiceNo := GetJSToken(jtEntity.AsObject(), 'bcInvoice').AsValue().AsText();
                EntryApply := GetJSToken(jtEntity.AsObject(), 'bcApply').AsValue().AsBoolean();
                if EntryApply then
                    idCRM := GetJSToken(jtEntity.AsObject(), 'crmId').AsValue().AsText();
                idBC := GetJSToken(jtEntity.AsObject(), 'bcId').AsValue().AsText();
                PaymentCRMOnUpdateIdAfterSend(PaymentNo, InvoiceNo, EntryApply, idCRM, true);
            end;
        end;
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
                EntityCRMOnUpdateIdAfterSend(entityType, Key1, '', idCRM, true);
            end;
        end;
    end;

    local procedure GetURLForPostEntity(entityType: Code[30]): Text
    begin
        IntegrationCRMSetup.Get(entityType);
        exit(StrSubstNo(lblSubStrURL, IntegrationCRMSetup.URL, IntegrationCRMSetup.Param));
    end;

    local procedure CreateRequestBodyForPostUoms(var requestBody: Text)
    var
        bodyArray: JsonArray;
        EntitySetup: Record "Entity Setup";
    begin
        EntitySetup.Get(lblUoM);
        if EntitySetup."Rows Number" = 0 then
            EntitySetup."Rows Number" += 1;

        repeat
            RecNo += 1;
            if UoM.Get(EntityCRM.Key1) then begin
                Clear(Body);

                Body.Add('bcid', Guid2APIStr(UoM.SystemId));
                Body.Add('name', UoM.Code);
                Body.Add('description', UoM.Description);

                bodyArray.Add(Body);
            end;

            AfterAddEntityToRequestBody();
        until (RecNo = EntitySetup."Rows Number") or (Recs = RecNo);

        bodyArray.WriteTo(requestBody);
    end;

    local procedure CreateRequestBodyForPostItemCategory(var requestBody: Text)
    var
        bodyArray: JsonArray;
        EntitySetup: Record "Entity Setup";
    begin
        EntitySetup.Get(lblItemCategory);
        if EntitySetup."Rows Number" = 0 then
            EntitySetup."Rows Number" += 1;

        repeat
            RecNo += 1;
            if ItemCategory.Get(EntityCRM.Key1) then begin
                Clear(Body);

                Body.Add('title', ItemCategory.Code);
                Body.Add('bcid', Guid2APIStr(ItemCategory.SystemId));
                Body.Add('category_number', ItemCategory.Indentation);
                if ItemCategory.Indentation > 0 then
                    Body.Add('parentcategoryid', Guid2APIStr(GetCategoryId(ItemCategory."Parent Category")));
                Body.Add('description', ItemCategory.Description);
                Body.Add('description_ru', ItemCategory."Description RU");

                bodyArray.Add(Body);
            end;

            AfterAddEntityToRequestBody();
        until (RecNo = EntitySetup."Rows Number") or (Recs = RecNo);

        bodyArray.WriteTo(requestBody);
    end;

    local procedure CreateRequestBodyForPostItems(var requestBody: Text)
    var
        bodyArray: JsonArray;
        EntitySetup: Record "Entity Setup";
    begin
        EntitySetup.Get(lblItem);
        if EntitySetup."Rows Number" = 0 then
            EntitySetup."Rows Number" += 1;

        repeat
            RecNo += 1;
            if Item.Get(EntityCRM.Key1) then begin
                Clear(Body);

                Body.Add('bcid', Guid2APIStr(Item.SystemId));
                Body.Add('item_number', Item."No.");
                Body.Add('description', DelChr(Item.Description + Item."Description 2", '=', '"'));
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
                    Body.Add('description_eng', Blob2TextFromRec(Database::"Item Description", ItemDescr.RecordId, ItemDescr.FieldNo(Description)));
                    Body.Add('ingredients', Blob2TextFromRec(Database::"Item Description", ItemDescr.RecordId, ItemDescr.FieldNo(Ingredients)));
                    Body.Add('indications', Blob2TextFromRec(Database::"Item Description", ItemDescr.RecordId, ItemDescr.FieldNo(Indications)));
                    Body.Add('directions', Blob2TextFromRec(Database::"Item Description", ItemDescr.RecordId, ItemDescr.FieldNo(Directions)));
                end;
                Body.Add('blocked', Item.Blocked or Item."Sales Blocked");
                Body.Add('blocked_reason', Item."Block Reason");
                Body.Add('baseuom', Guid2APIStr(GetUoMIdByCode(Item."Base Unit of Measure")));
                Body.Add('price', Item."Unit Price");
                Body.Add('promotional_price', GetPromotionalPrice(Item."No."));
                Body.Add('productuom', GetItemUoM(Item."No."));
                if glManufacturer.Get(Item."Manufacturer Code") then begin
                    Body.Add('manufacturer_eng', glManufacturer.Name);
                    Body.Add('manufacturer_ru', glManufacturer."Name RU");
                end;
                if glBrand.Get(Item."Brand Code", Item."Manufacturer Code") then begin
                    Body.Add('brand_eng', glBrand.Name);
                    Body.Add('brand_ru', glBrand."Name RU");
                end;

                if ItemCategory.Get(Item."Item Category Code") then
                    Body.Add('category', Guid2APIStr(ItemCategory.SystemId));

                if ItemFilterGroupExist(Item."No.") then
                    Body.Add('filters_group', jsonGetFilterGroupArray(Item."No."));

                bodyArray.Add(Body);
            end;

            AfterAddEntityToRequestBody();
        until (RecNo = EntitySetup."Rows Number") or (Recs = RecNo);

        bodyArray.WriteTo(requestBody);
    end;

    local procedure AfterAddPaymentToRequestBody(var PaymentCRM: Record "Payment CRM")
    begin
        if GuiAllowed then
            Window.Update(2, RecNo);

        if RecNo < 100 then
            PaymentCRM.Next();

        if (RecNo = 100) then
            PaymentCRM.SetFilter("Payment Entry No.", '%1..', PaymentCRM."Payment Entry No.")
        else
            if (Recs = RecNo) then
                PaymentCRM.SetFilter("Payment Entry No.", '%1..', PaymentCRM."Payment Entry No." + 1);
    end;

    local procedure AfterAddEntityToRequestBody()
    begin
        if GuiAllowed then
            Window.Update(2, RecNo);

        if RecNo < 100 then
            EntityCRM.Next();

        if (RecNo = 100) then
            EntityCRM.SetFilter(Key1, '%1..', EntityCRM.Key1)
        else
            if (Recs = RecNo) then
                EntityCRM.SetFilter(Key1, '%1..', IncStr(EntityCRM.Key1));
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

                locJsonObject.Add('uom_id', Guid2APIStr(GetUoMIdByCode(locUoM.Code)));
                locJsonObject.Add('bcid', Guid2APIStr(locItemUoM.SystemId));
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
        EntitySetup: Record "Entity Setup";
    begin
        EntitySetup.Get(lblCustomer);
        if EntitySetup."Rows Number" = 0 then
            EntitySetup."Rows Number" += 1;

        repeat
            RecNo += 1;
            if Customer.Get(EntityCRM.Key1) then begin
                Customer.CalcFields("Balance (LCY)", "Balance Due (LCY)", "Payments (LCY)");
                Clear(Body);

                Body.Add('bcid', Guid2APIStr(Customer.SystemId));
                Body.Add('bc_number', Customer."No.");
                Body.Add('name', Customer.Name + Customer."Name 2");
                Body.Add('balance', Customer."Balance (LCY)");
                Body.Add('balance_due', Customer."Balance Due (LCY)");
                Body.Add('credit_limit', Customer."Credit Limit (LCY)");
                Body.Add('total_sales', CustomerGetTotalSales(Customer."No."));
                Body.Add('payments', Customer."Payments (LCY)");
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

            AfterAddEntityToRequestBody();
        until (RecNo = EntitySetup."Rows Number") or (Recs = RecNo);

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
        EntitySetup: Record "Entity Setup";
    begin
        EntitySetup.Get(lblInvoice);
        if EntitySetup."Rows Number" = 0 then
            EntitySetup."Rows Number" += 1;

        repeat
            RecNo += 1;
            if SalesInvHeader.Get(EntityCRM.Key1) then begin
                Clear(Body);

                Body.Add('bcid', Guid2APIStr(SalesInvHeader.SystemId));
                Body.Add('invoice_number', SalesInvHeader."No.");
                Body.Add('customer_id', SalesInvHeader."Sell-to Customer No.");
                Body.Add('date_delivered', Date2APIStr(SalesInvHeader."Posting Date"));
                Body.Add('due_date', Date2APIStr(SalesInvHeader."Due Date"));
                Body.Add('sales_order_no', SalesInvHeader."Order No.");
                Body.Add('currency_id', SalesInvHeader."Currency Code");
                Body.Add('shipment_date', Date2APIStr(SalesInvHeader."Shipment Date"));
                Body.Add('invoice_detail', GetInvoiceLine(SalesInvHeader."No."));
                Body.Add('charge_delivery', GetAmountDelivery(SalesInvHeader."No.", SalesInvHeader."Sell-to Customer No."));

                bodyArray.Add(Body);
            end;

            AfterAddEntityToRequestBody();
        until (RecNo = EntitySetup."Rows Number") or (Recs = RecNo);

        bodyArray.WriteTo(requestBody);
    end;

    local procedure GetInvoiceLine(InvoiceNo: Code[20]): JsonArray
    var
        locSIL: Record "Sales Invoice Line";
        locJsonObject: JsonObject;
        locJsonArray: JsonArray;
    begin
        boolTrue := true;

        locSIL.SetRange("Document No.", InvoiceNo);
        locSIL.SetRange(Type, locSIL.Type::Item);
        locSIL.SetFilter(Quantity, '<>%1', 0);
        if locSIL.FindSet() then
            repeat
                Clear(locJsonObject);

                locJsonObject.Add('bcid', Guid2APIStr(locSIL.SystemId));
                locJsonObject.Add('product', locSIL."No.");
                locJsonObject.Add('quantity', locSIL.Quantity);
                locJsonObject.Add('uom_id', Guid2APIStr(GetUoMIdByCode(locSIL."Unit of Measure Code")));
                locJsonObject.Add('price_perunit', locSIL."Unit Price");
                if locSIL."Allow Line Disc." then
                    locJsonObject.Add('discount_amount', locSIL."Line Discount Amount");
                if locSIL."Allow Invoice Disc." then
                    locJsonObject.Add('inv_discount_amount', locSIL."Line Discount Amount");
                locJsonObject.Add('price', boolTrue);

                locJsonArray.Add(locJsonObject);
            until locSIL.Next() = 0;

        exit(locJsonArray);
    end;

    local procedure GetAmountDelivery(SalesInvoiceNo: Code[20]; CustomerCode: Code[20]): Decimal
    var
        locCust: Record Customer;
        locSIL: Record "Sales Invoice Line";
    begin
        locCust.Get(CustomerCode);
        locSIL.SetCurrentKey("Document No.", Type, "No.");
        locSIL.SetRange("Document No.", SalesInvoiceNo);
        locSIL.SetRange(Type, locSIL.Type::"Charge (Item)");
        locSIL.SetRange("No.", locCust."Sales No. Shipment Cost");
        locSIL.CalcSums("Amount Including VAT");
        exit(locSIL."Amount Including VAT");
    end;

    local procedure CreateRequestBodyForPostPackage(var requestBody: Text)
    var
        bodyArray: JsonArray;
        EntitySetup: Record "Entity Setup";
    begin
        EntitySetup.Get(lblPackage);
        if EntitySetup."Rows Number" = 0 then
            EntitySetup."Rows Number" += 1;

        repeat
            RecNo += 1;
            if PackageHeader.Get(EntityCRM.Key1) then begin
                Clear(Body);

                Body.Add('bcid', Guid2APIStr(PackageHeader.SystemId));
                Body.Add('package_number', PackageHeader."No.");
                Body.Add('sales_order_no', PackageHeader."Sales Order No.");
                Body.Add('create_on', DateTime2APIStr(PackageHeader."Create Date"));
                Body.Add('status_code', Format(PackageHeader.Status));
                Body.Add('boxes', GetBoxesByPackage(PackageHeader."No."));

                bodyArray.Add(Body);
            end;

            AfterAddEntityToRequestBody();
        until (RecNo = EntitySetup."Rows Number") or (Recs = RecNo);

        bodyArray.WriteTo(requestBody);
    end;

    local procedure GetBoxesByPackage(PackageNo: Code[20]): JsonArray
    var
        locJsonObject: JsonObject;
        locJsonArray: JsonArray;
    begin
        BoxHeader.Reset();
        BoxHeader.SetRange("Package No.", PackageNo);
        if not BoxHeader.FindSet() then exit;

        repeat
            Clear(locJsonObject);

            locJsonObject.Add('bcid', Guid2APIStr(BoxHeader.SystemId));
            locJsonObject.Add('box_number', BoxHeader."No.");
            locJsonObject.Add('create_on', DateTime2APIStr(BoxHeader."Create Date"));
            locJsonObject.Add('status_code', Format(BoxHeader.Status));
            locJsonObject.Add('external_document_no', BoxHeader."External Document No.");
            locJsonObject.Add('box_code', BoxHeader."Box Code");
            locJsonObject.Add('gross_weight', BoxHeader."Gross Weight");
            locJsonObject.Add('uom_weight', Format(BoxHeader."Unit of Measure"));
            locJsonObject.Add('tracking_no', BoxHeader."Tracking No.");
            locJsonObject.Add('shipping_agent_id', BoxHeader."Shipping Agent Code");
            locJsonObject.Add('shipping_agent_service_id', BoxHeader."Shipping Services Code");
            locJsonObject.Add('shipstation_statuscode', BoxHeader."ShipStation Status");
            locJsonObject.Add('shipstation_shipment_id', BoxHeader."ShipStation Shipment ID");
            locJsonObject.Add('shipstation_order_id', BoxHeader."ShipStation Order ID");
            locJsonObject.Add('shipstation_order_key', BoxHeader."ShipStation Order Key");
            locJsonObject.Add('boxes_line', GetBoxesLineByBox(BoxHeader."No."));
            locJsonObject.Add('quantity', PackageBoxMgt.GetQuantityInBox(BoxHeader."No."));

            locJsonArray.Add(locJsonObject);
        until BoxHeader.Next() = 0;

        exit(locJsonArray);
    end;

    local procedure GetBoxesLineByBox(BoxNo: Code[20]): JsonArray
    var
        locJsonObject: JsonObject;
        locJsonArray: JsonArray;
    begin
        BoxLine.Reset();
        BoxLine.SetRange("Box No.", BoxNo);
        if not BoxLine.FindSet() then exit;

        repeat
            Clear(locJsonObject);

            locJsonObject.Add('bcid', Guid2APIStr(BoxLine.SystemId));
            locJsonObject.Add('line_number', BoxLine."Line No.");
            locJsonObject.Add('item_number', BoxLine."Item No.");
            locJsonObject.Add('quantity', BoxLine."Quantity in Box");

            locJsonArray.Add(locJsonObject);
        until BoxLine.Next() = 0;

        exit(locJsonArray);
    end;

    local procedure CreateRequestBodyForPostUpdateOrder(var requestBody: Text)
    var
        bodyArray: JsonArray;
        EntitySetup: Record "Entity Setup";
        locSalesHeader: Record "Sales Header";
        locSalesHeaderArchive: Record "Sales Header Archive";
    begin
        EntitySetup.Get(lblUpdateOrder);
        if EntitySetup."Rows Number" = 0 then
            EntitySetup."Rows Number" += 1;

        GetSRSetup();

        repeat
            RecNo += 1;
            if locSalesHeader.Get(locSalesHeader."Document Type"::Order, EntityCRM.Key1) then begin
                Clear(Body);

                Body.Add('bcid', Guid2APIStr(locSalesHeader.SystemId));
                Body.Add('sales_order_no', locSalesHeader."No.");
                Body.Add('crm_order_no', locSalesHeader."External Document No.");
                Body.Add('customerid', locSalesHeader."Sell-to Customer No.");
                Body.Add('duedate', Date2APIStr(locSalesHeader."Due Date"));
                Body.Add('orderdate', Date2APIStr(locSalesHeader."Order Date"));
                if locSalesHeader."Requested Delivery Date" <> 0D then
                    Body.Add('requestdelivery', Date2APIStr(locSalesHeader."Requested Delivery Date"));
                Body.Add('documentdate', Date2APIStr(locSalesHeader."Document Date"));
                Body.Add('postingdate', Date2APIStr(locSalesHeader."Posting Date"));
                Body.Add('shipmentdate', Date2APIStr(locSalesHeader."Shipment Date"));
                Body.Add('prepayment_duedate', Date2APIStr(locSalesHeader."Prepayment Due Date"));
                if locSalesHeader."Promised Delivery Date" <> 0D then
                    Body.Add('promiseddelivery', Date2APIStr(locSalesHeader."Promised Delivery Date"));
                Body.Add('lines', GetLinesByOrder(locSalesHeader."No."));

                // locSalesHeader.CalcFields(Amount, "Amount Including VAT", "Invoice Discount Amount");
                // if InvoiceDiscountAllowed(locSalesHeader."No.") then
                //     Body.Add('order_discount_amount', locSalesHeader."Invoice Discount Amount");
                // Body.Add('order_vat_base_amount', locSalesHeader.Amount);
                // Body.Add('order_amount_incl_vat', locSalesHeader."Amount Including VAT");

                bodyArray.Add(Body);
            end else begin
                if SRSetup."Archive Orders" then begin
                    locSalesHeaderArchive.SetCurrentKey("No.", "Version No.");
                    locSalesHeaderArchive.SetRange("Document Type", locSalesHeaderArchive."Document Type"::Order);
                    locSalesHeaderArchive.SetRange("No.", EntityCRM.Key1);
                    if locSalesHeaderArchive.FindLast() then begin
                        Clear(Body);

                        Body.Add('bcid', Guid2APIStr(locSalesHeaderArchive.SystemId));
                        Body.Add('sales_order_no', locSalesHeaderArchive."No.");
                        Body.Add('crm_order_no', locSalesHeaderArchive."External Document No.");
                        Body.Add('customerid', locSalesHeaderArchive."Sell-to Customer No.");
                        Body.Add('duedate', Date2APIStr(locSalesHeaderArchive."Due Date"));
                        Body.Add('orderdate', Date2APIStr(locSalesHeaderArchive."Order Date"));
                        if locSalesHeaderArchive."Requested Delivery Date" <> 0D then
                            Body.Add('requestdelivery', Date2APIStr(locSalesHeaderArchive."Requested Delivery Date"));
                        Body.Add('documentdate', Date2APIStr(locSalesHeaderArchive."Document Date"));
                        Body.Add('postingdate', Date2APIStr(locSalesHeaderArchive."Posting Date"));
                        Body.Add('shipmentdate', Date2APIStr(locSalesHeaderArchive."Shipment Date"));
                        Body.Add('prepayment_duedate', Date2APIStr(locSalesHeaderArchive."Prepayment Due Date"));
                        if locSalesHeaderArchive."Promised Delivery Date" <> 0D then
                            Body.Add('promiseddelivery', Date2APIStr(locSalesHeaderArchive."Promised Delivery Date"));
                        Body.Add('lines', GetLinesByOrder(locSalesHeaderArchive."No."));

                        // locSalesHeaderArchive.CalcFields(Amount, "Amount Including VAT", "Invoice Discount Amount");
                        // if InvoiceDiscountAllowed(locSalesHeaderArchive."No.") then
                        //     Body.Add('order_discount_amount', locSalesHeaderArchive."Invoice Discount Amount");
                        // Body.Add('order_vat_base_amount', locSalesHeaderArchive.Amount);
                        // Body.Add('order_amount_incl_vat', locSalesHeaderArchive."Amount Including VAT");

                        bodyArray.Add(Body);
                    end;
                end;
            end;
            AfterAddEntityToRequestBody();
        until (RecNo = EntitySetup."Rows Number") or (Recs = RecNo);

        bodyArray.WriteTo(requestBody);
    end;

    local procedure GetLinesByOrder(OrderNo: Code[20]): JsonArray
    var
        locJsonObject: JsonObject;
        locJsonArray: JsonArray;
        locSalesLine: Record "Sales Line";
        locSalesLineArchive: Record "Sales Line Archive";
        locItemUoM: Record "Item Unit of Measure";
        locUoM: Record "Unit of Measure";
    begin
        locSalesLine.SetCurrentKey("Document Type", "Document No.", "Line No.", Type, Quantity);
        locSalesLine.SetRange(locSalesLine."Document Type", locSalesLine."Document Type"::Order);
        locSalesLine.SetRange("Document No.", OrderNo);
        locSalesLine.SetRange(Type, locSalesLine.Type::Item);
        locSalesLine.SetFilter(Quantity, '<>%1', 0);
        if locSalesLine.FindSet() then begin
            repeat
                Clear(locJsonObject);

                locJsonObject.Add('bcid', Guid2APIStr(locSalesLine.SystemId));
                locJsonObject.Add('line_no', locSalesLine."Line No.");
                locJsonObject.Add('item_no', locSalesLine."No.");

                // locItemUoM.Get(locSalesLine."No.", locSalesLine."Unit of Measure Code");
                // locJsonObject.Add('uom_id', Guid2APIStr(locItemUoM.SystemId));
                locUoM.Get(locSalesLine."Unit of Measure Code");
                locJsonObject.Add('uom_id', Guid2APIStr(locUoM.SystemId));

                locJsonObject.Add('quantity', locSalesLine.Quantity);
                locJsonObject.Add('unit_price', locSalesLine."Unit Price");
                locJsonObject.Add('vat_base_amount', locSalesLine."VAT Base Amount");
                locJsonObject.Add('amount_incl_vat', locSalesLine."Amount Including VAT");
                if locSalesLine."Allow Line Disc." then
                    locJsonObject.Add('line_discount_amount', locSalesLine."Line Discount Amount");
                if locSalesLine."Allow Invoice Disc." then
                    locJsonObject.Add('inv_discount_amount', locSalesLine."Inv. Discount Amount");

                locJsonArray.Add(locJsonObject);
            until locSalesLine.Next() = 0;
        end else begin
            if SRSetup."Archive Orders" then begin
                locSalesLineArchive.SetCurrentKey("Document Type", "Document No.", "Line No.", Type, Quantity, "Version No.");
                locSalesLineArchive.SetRange(locSalesLineArchive."Document Type", locSalesLineArchive."Document Type"::Order);
                locSalesLineArchive.SetRange("Document No.", OrderNo);
                locSalesLineArchive.SetRange(Type, locSalesLineArchive.Type::Item);
                locSalesLineArchive.SetFilter(Quantity, '<>%1', 0);
                locSalesLineArchive.SetRange("Version No.", GetVersionNo(OrderNo));
                if locSalesLineArchive.FindSet() then begin
                    repeat
                        Clear(locJsonObject);

                        locJsonObject.Add('bcid', Guid2APIStr(locSalesLineArchive.SystemId));
                        locJsonObject.Add('line_no', locSalesLineArchive."Line No.");
                        locJsonObject.Add('item_no', locSalesLineArchive."No.");

                        // locItemUoM.Get(locSalesLineArchive."No.", locSalesLineArchive."Unit of Measure Code");
                        // locJsonObject.Add('uom_id', Guid2APIStr(locItemUoM.SystemId));
                        locUoM.Get(locSalesLineArchive."Unit of Measure Code");
                        locJsonObject.Add('uom_id', Guid2APIStr(locUoM.SystemId));

                        locJsonObject.Add('quantity', locSalesLineArchive.Quantity);
                        locJsonObject.Add('unit_price', locSalesLineArchive."Unit Price");
                        locJsonObject.Add('vat_base_amount', locSalesLineArchive."VAT Base Amount");
                        locJsonObject.Add('amount_incl_vat', locSalesLineArchive."Amount Including VAT");
                        if locSalesLineArchive."Allow Line Disc." then
                            locJsonObject.Add('line_discount_amount', locSalesLineArchive."Line Discount Amount");
                        if locSalesLineArchive."Allow Invoice Disc." then
                            locJsonObject.Add('inv_discount_amount', locSalesLineArchive."Inv. Discount Amount");

                        locJsonArray.Add(locJsonObject);
                    until locSalesLineArchive.Next() = 0;
                end;
            end;
        end;

        exit(locJsonArray);
    end;


    local procedure GetVersionNo(OrderNo: Code[20]): Integer
    var
        locSalesHeaderArchive: Record "Sales Header Archive";
    begin
        locSalesHeaderArchive.SetCurrentKey("Document Type", "No.", "Version No.");
        locSalesHeaderArchive.SetRange("Document Type", locSalesHeaderArchive."Document Type"::Order);
        locSalesHeaderArchive.SetRange("No.", OrderNo);
        locSalesHeaderArchive.FindLast();
        exit(locSalesHeaderArchive."Version No.");
    end;

    local procedure InvoiceDiscountAllowed(OrderNo: Code[20]): Boolean
    var
        locSalesLine: Record "Sales Line";
    begin
        locSalesLine.SetCurrentKey("Document Type", "Document No.", Type, Quantity);
        locSalesLine.SetRange(locSalesLine."Document Type", locSalesLine."Document Type"::Order);
        locSalesLine.SetRange("Document No.", OrderNo);
        locSalesLine.SetRange(Type, locSalesLine.Type::Item);
        locSalesLine.SetFilter(Quantity, '<>%1', 0);
        exit(locSalesLine.FindFirst() and locSalesLine."Allow Invoice Disc.");
    end;

    local procedure CreateRequestBodyForPostOrderStatus(var requestBody: Text)
    var
        bodyArray: JsonArray;
        EntitySetup: Record "Entity Setup";
    begin
        EntitySetup.Get(lblOrderStatus);
        if EntitySetup."Rows Number" = 0 then
            EntitySetup."Rows Number" += 1;

        repeat
            RecNo += 1;
            if not IsNullGuid(EntityCRM."Id CRM") then begin
                Clear(Body);

                Body.Add('crm_id', Guid2APIStr(EntityCRM."Id CRM"));
                Body.Add('bc_id', Guid2APIStr(EntityCRM."Id BC"));
                Body.Add('bc_number', EntityCRM.Key1);
                Body.Add('bc_order_status', GetOrderStatusByOrderNo(EntityCRM.Key1));

                bodyArray.Add(Body);
            end;

            AfterAddEntityToRequestBody();
        until (RecNo = EntitySetup."Rows Number") or (Recs = RecNo);

        bodyArray.WriteTo(requestBody);
    end;

    local procedure GetOrderStatusByOrderNo(OrderNo: Code[20]): Text[20]
    var
        SalesHeader: Record "Sales Header";
        SalesInvHeader: Record "Sales Invoice Header";
    begin
        if SalesHeader.Get(SalesHeader."Document Type"::Order, OrderNo) then
            exit(lblOrderInProgress);

        SalesInvHeader.SetCurrentKey("Order No.");
        SalesInvHeader.SetRange("Order No.", OrderNo);
        if SalesInvHeader.IsEmpty then
            exit(lblOrderCancelled);

        exit(lblOrderCompleted);
    end;

    local procedure CreateRequestBodyForPostPayment(var PaymentCRM: Record "Payment CRM"; var requestBody: Text)
    var
        bodyArray: JsonArray;
        locEntityCRM: Record "Entity CRM";
        EntitySetup: Record "Entity Setup";
    begin
        EntitySetup.Get(lblPayment);
        if EntitySetup."Rows Number" = 0 then
            EntitySetup."Rows Number" += 1;

        repeat
            RecNo += 1;

            if locEntityCRM.Get(lblInvoice, PaymentCRM."Invoice No.", '') and not IsNullGuid(locEntityCRM."Id CRM") then begin
                Clear(Body);

                Body.Add('crm_invoiceid', Guid2APIStr(locEntityCRM."Id CRM"));
                Body.Add('crm_salesorderid', Guid2APIStr(GetOrderCRMId(PaymentCRM."Invoice No.")));
                Body.Add('bcid', Guid2APIStr(PaymentCRM."Id BC"));
                Body.Add('bc_number', PaymentCRM."Payment No.");
                Body.Add('bc_invoice_number', PaymentCRM."Invoice No.");
                Body.Add('payment_amount', PaymentCRM.Amount);
                Body.Add('payment_date', PaymentCRM."Payment Date");
                Body.Add('apply', PaymentCRM.Apply);

                bodyArray.Add(Body);
            end;

            AfterAddPaymentToRequestBody(PaymentCRM);
        until (RecNo = EntitySetup."Rows Number") or (Recs = RecNo);

        bodyArray.WriteTo(requestBody);
    end;

    local procedure CreateRequestBodyForPostInvoiceStatus(var requestBody: Text)
    var
        bodyArray: JsonArray;
        EntitySetup: Record "Entity Setup";
    begin
        EntitySetup.Get(lblInvoiceStatus);
        if EntitySetup."Rows Number" = 0 then
            EntitySetup."Rows Number" += 1;

        repeat
            RecNo += 1;
            if not IsNullGuid(EntityCRM."Id CRM") then begin
                Clear(Body);

                Body.Add('crm_id', Guid2APIStr(EntityCRM."Id CRM"));
                Body.Add('bc_id', Guid2APIStr(EntityCRM."Id BC"));
                Body.Add('bc_number', EntityCRM.Key1);
                Body.Add('bc_invoice_status', GetInvoiceStatusByInvoiceNo(EntityCRM.Key1));

                bodyArray.Add(Body);
            end;

            AfterAddEntityToRequestBody();
        until (RecNo = EntitySetup."Rows Number") or (Recs = RecNo);

        bodyArray.WriteTo(requestBody);
    end;

    local procedure GetInvoiceStatusByInvoiceNo(InvoiceNo: Code[20]): Text[20]
    var
        SalesInvHeader: Record "Sales Invoice Header";
        CustLedgEntry: Record "Cust. Ledger Entry";
    begin
        SalesInvHeader.Get(InvoiceNo);
        CustLedgEntry.SetCurrentKey("Document No.", "Posting Date");
        CustLedgEntry.SetRange("Document No.", SalesInvHeader."No.");
        CustLedgEntry.SetRange("Posting Date", SalesInvHeader."Posting Date");
        CustLedgEntry.FindFirst();
        if CustLedgEntry.Open then begin
            if CustLedgEntry."Due Date" > DT2Date(CurrentDateTime) then
                exit(lblInvoiceOpen)
            else
                exit(lblInvoiceOverdue);
        end;

        exit(lblInvoicePaid);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Release Sales Document", 'OnAfterReleaseSalesDoc', '', false, false)]
    local procedure OrderOnAfterModifyEvent(var SalesHeader: Record "Sales Header"; PreviewMode: Boolean)
    begin
        if PreviewMode then exit;

        if SalesOrderFromCRM(SalesHeader."No.") then begin
            EntityCRMOnUpdateIdBeforeSend(lblOrderStatus, SalesHeader."No.", '', SalesHeader.SystemId);
            EntityCRMOnUpdateIdAfterSend(lblOrderStatus, SalesHeader."No.", '', SalesHeader."CRM ID", false);

            EntityCRMOnUpdateIdBeforeSend(lblUpdateOrder, SalesHeader."No.", '', SalesHeader.SystemId);
        end;
    end;

    [EventSubscriber(ObjectType::Table, 36, 'OnBeforeDeleteEvent', '', false, false)]
    local procedure OrderOnAfterDeleteEvent(var Rec: Record "Sales Header")
    begin
        if SalesOrderFromCRM(Rec."No.") then begin
            EntityCRMOnUpdateIdBeforeSend(lblOrderStatus, Rec."No.", '', Rec.SystemId);
            EntityCRMOnUpdateIdAfterSend(lblOrderStatus, Rec."No.", '', Rec."CRM ID", false);
        end;
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

    [EventSubscriber(ObjectType::Table, 5722, 'OnAfterInsertEvent', '', false, false)]
    local procedure ItemCategoryOnAfterInsertEvent(var Rec: Record "Item Category")
    begin
        EntityCRMOnUpdateIdBeforeSend(lblItemCategory, Rec.Code, '', Rec.SystemId);
    end;

    [EventSubscriber(ObjectType::Table, 5722, 'OnAfterModifyEvent', '', false, false)]
    local procedure ItemCategoryOnAfterModifyEvent(var Rec: Record "Item Category")
    begin
        EntityCRMOnUpdateIdBeforeSend(lblItemCategory, Rec.Code, '', Rec.SystemId);
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

    [EventSubscriber(ObjectType::Table, 50000, 'OnAfterModifyEvent', '', false, false)]
    local procedure ItemDescriptionOnAfterModifyEvent(var Rec: Record "Item Description")
    var
        locItem: Record Item;
    begin
        locItem.Get(Rec."Item No.");
        EntityCRMOnUpdateIdBeforeSend(lblItem, locItem."No.", '', locItem.SystemId);
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
    var
        locPackageHeader: Record "Package Header";
    begin
        if SalesOrderFromCRM(Rec."Order No.") then begin
            EntityCRMOnUpdateIdBeforeSend(lblInvoice, Rec."No.", '', Rec.SystemId);

            locPackageHeader.SetRange("Sales Order No.", Rec."Order No.");
            if locPackageHeader.FindFirst() then
                EntityCRMOnUpdateIdBeforeSend(lblPackage, locPackageHeader."No.", '', locPackageHeader.SystemId);

        end;
    end;

    [EventSubscriber(ObjectType::Table, 112, 'OnAfterModifyEvent', '', false, false)]
    local procedure SalesInvOnAfterModifyEvent(var Rec: Record "Sales Invoice Header")
    var
        locPackageHeader: Record "Package Header";
    begin
        if SalesOrderFromCRM(Rec."Order No.") then begin
            EntityCRMOnUpdateIdBeforeSend(lblInvoice, Rec."No.", '', Rec.SystemId);

            PackageHeader.SetRange("Sales Order No.", Rec."Order No.");
            if PackageHeader.FindFirst() then
                EntityCRMOnUpdateIdBeforeSend(lblPackage, locPackageHeader."No.", '', locPackageHeader.SystemId);
        end;
    end;

    [EventSubscriber(ObjectType::Table, 50071, 'OnAfterModifyEvent', '', false, false)]
    local procedure CLEOnAfterInsertEvent(var Rec: Record "Entity CRM")
    var
        locSalesInvHeader: Record "Sales Invoice Header";
        locCLE: Record "Cust. Ledger Entry";
    begin
        if not (Rec.Code = lblInvoice) then
            exit;

        SalesInvHeader.Get(Rec.Key1);
        locCLE.Get(SalesInvHeader."Cust. Ledger Entry No.");
        if SalesOrderFromCRM(SalesInvHeader."Order No.") then begin
            InvoiceStatusCRMOnUpdateIdBeforeSend(lblInvoiceStatus, Rec.Key1, '', Rec."Id BC");
            InvoiceStatusUpdate(lblInvoiceStatus, Rec.Key1, '', locCLE.Open);
        end;
    end;

    [EventSubscriber(ObjectType::Table, 21, 'OnBeforeValidateEvent', 'Due Date', false, false)]
    local procedure CLEOnBeforeModifyEvent(var xRec: Record "Cust. Ledger Entry"; var Rec: Record "Cust. Ledger Entry"; CurrFieldNo: Integer)
    var
        locSalesInvHeader: Record "Sales Invoice Header";
        locEntityCRM: Record "Entity CRM";
    begin
        if (xRec."Due Date" = Rec."Due Date")
        and not (Rec."Document Type" = Rec."Document Type"::Invoice) then
            exit;

        if locSalesInvHeader.Get(Rec."Document No.")
        and SalesOrderFromCRM(locSalesInvHeader."Order No.") then begin
            InvoiceStatusCRMOnUpdateIdBeforeSend(lblInvoiceStatus, locSalesInvHeader."No.", '', locSalesInvHeader.SystemId);
            InvoiceStatusUpdate(lblInvoiceStatus, Rec."Document No.", '', Rec.Open);
        end;
    end;

    [EventSubscriber(ObjectType::Table, 21, 'OnAfterModifyEvent', '', false, false)]
    local procedure CLEOnAfterModifyEvent(var Rec: Record "Cust. Ledger Entry")
    var
        locSalesInvHeader: Record "Sales Invoice Header";
        locEntityCRM: Record "Entity CRM";
    begin
        if not (Rec."Document Type" = Rec."Document Type"::Invoice) then
            exit;

        if locSalesInvHeader.Get(Rec."Document No.")
        and SalesOrderFromCRM(locSalesInvHeader."Order No.") then begin
            if locEntityCRM.Get(lblInvoiceStatus, Rec."Document No.", '') then begin
                if locEntityCRM."Invoice Open" <> Rec.Open then begin
                    InvoiceStatusCRMOnUpdateIdBeforeSend(lblInvoiceStatus, locSalesInvHeader."No.", '', locSalesInvHeader.SystemId);
                    InvoiceStatusUpdate(lblInvoiceStatus, Rec."Document No.", '', Rec.Open);
                end;
            end else begin
                InvoiceStatusCRMOnUpdateIdBeforeSend(lblInvoiceStatus, locSalesInvHeader."No.", '', locSalesInvHeader.SystemId);
                InvoiceStatusUpdate(lblInvoiceStatus, Rec."Document No.", '', Rec.Open);
            end;
        end;
    end;

    // [EventSubscriber(ObjectType::Table, 271, 'OnAfterInsertEvent', '', false, false)]
    local procedure BALEOnAfterInsertEvent(var Rec: Record "Bank Account Ledger Entry")
    begin
        if Rec."Reversed Entry No." <> 0 then exit;
        // if not CustomerExistInCRM() then exit;

        EntityCRMOnUpdateIdBeforeSend(lblPayment, Rec."Document No.", '', Rec.SystemId);
    end;

    // [EventSubscriber(ObjectType::Table, 271, 'OnAfterModifyEvent', '', false, false)]
    local procedure BALEOnAfterModifyEvent(var Rec: Record "Bank Account Ledger Entry")
    begin
        if Rec."Reversed Entry No." <> 0 then exit;
        // if not CustomerExistInCRM(Rec."Bal. Account Type", Rec."Bal. Account No.") then exit;

        EntityCRMOnUpdateIdBeforeSend(lblPayment, Rec."Document No.", '', Rec.SystemId);
        if Rec."Reversed by Entry No." <> 0 then
            UpdateEntityCRM(lblPayment, Rec."Document No.", false);
    end;

    // [EventSubscriber(ObjectType::Codeunit, 50050, 'OnAfterRegisterPackage', '', false, false)]
    local procedure PackageOnAfterInsertEvent(PackageNo: Code[20])
    var
        locPackageHeader: Record "Package Header";
    begin
        if locPackageHeader.Get(PackageNo)
        and SalesOrderFromCRM(locPackageHeader."Sales Order No.") then
            EntityCRMOnUpdateIdBeforeSend(lblPackage, locPackageHeader."No.", '', locPackageHeader.SystemId);
    end;

    local procedure InsertEntityCRM(entityType: Text[30]; Key1: Code[20]; Key2: Code[20]; IdBC: Guid)
    var
        locEntityCRM: Record "Entity CRM";
    begin
        if not CheckEnableIntegrationCRM() then exit;

        if locEntityCRM.Get(entityType, Key1, Key2)
        and (locEntityCRM.Rank = GetEntityRank(entityType, Key1)) then
            exit;

        locEntityCRM.Init();
        locEntityCRM.Code := entityType;
        locEntityCRM.Key1 := Key1;
        locEntityCRM.Key2 := Key2;
        locEntityCRM."Id BC" := IdBC;
        locEntityCRM.Rank := GetEntityRank(entityType, Key1);
        locEntityCRM.Insert(true);
    end;

    procedure EntityCRMOnUpdateIdBeforeSend(entityType: Text[30]; Key1: Code[20]; Key2: Code[20]; IdBC: Guid)
    var
        locEntityCRM: Record "Entity CRM";
    begin
        // check enable integration CRM
        if not CheckEnableIntegrationCRM() or (Key1 = '') then exit;
        // check item fields filled
        // if entityType = lblItem then
        //     if not CheckItemFieldsFilled(Key1) then exit;

        if not locEntityCRM.Get(entityType, Key1, Key2) then begin
            InsertEntityCRM(entityType, Key1, Key2, IdBC);
            exit;
        end;


        locEntityCRM."Modify In CRM" := false;
        locEntityCRM.Modify(true);
    end;

    local procedure EntityCRMOnUpdateIdAfterSend(entityType: Text[30]; Key1: Code[20]; Key2: Code[20]; idCRM: Guid; ModifyInCRM: Boolean)
    var
        locEntityCRM: Record "Entity CRM";
    begin
        // check enable integration CRM
        if not CheckEnableIntegrationCRM() or (Key1 = '') then exit;

        locEntityCRM.Get(entityType, Key1, Key2);
        locEntityCRM."Id CRM" := idCRM;
        locEntityCRM."Modify In CRM" := ModifyInCRM;
        locEntityCRM.Modify(true);
    end;

    local procedure PaymentCRMOnUpdateIdAfterSend(_PaymentNo: Code[20]; _InvoiceNo: Code[20]; _Apply: Boolean; idCRM: Guid; ModifyInCRM: Boolean)
    var
        locPaymentCRM: Record "Payment CRM";
    begin
        // check enable integration CRM
        if not CheckEnableIntegrationCRM() or (_PaymentNo = '') or (_InvoiceNo = '') then exit;

        locPaymentCRM.SetRange("Payment No.", _PaymentNo);
        locPaymentCRM.SetRange("Invoice No.", _InvoiceNo);
        locPaymentCRM.SetRange(Apply, _Apply);
        locPaymentCRM.FindFirst();
        locPaymentCRM."Id CRM" := idCRM;
        locPaymentCRM."Modify In CRM" := ModifyInCRM;
        locPaymentCRM.Modify(true);
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
        PostAllItemCategories();
        PostAllItems();
        PostAllCustomers();
        PostAllInvoices();
        PostAllPackages();
    end;

    procedure PostAllUoM()
    begin
        UoM.Reset();
        if UoM.FindSet() then
            repeat
                EntityCRMOnUpdateIdBeforeSend(lblUoM, UoM.Code, '', UoM.SystemId);
            until UoM.Next() = 0;
    end;

    procedure PostAllItemCategories()
    begin
        ItemCategory.Reset();
        ItemCategory.SetCurrentKey(Indentation);
        if ItemCategory.FindSet() then
            repeat
                EntityCRMOnUpdateIdBeforeSend(lblItemCategory, ItemCategory.Code, '', ItemCategory.SystemId);
            until ItemCategory.Next() = 0;
    end;

    procedure PostAllItems()
    begin
        Item.Reset();
        if Item.FindSet() then
            repeat
                EntityCRMOnUpdateIdBeforeSend(lblItem, Item."No.", '', Item.SystemId);
            until Item.Next() = 0;
    end;

    procedure PostAllCustomers()
    var
        locEntityCRM: Record "Entity CRM";
    begin
        Customer.Reset();
        if Customer.FindSet() then
            repeat
                EntityCRMOnUpdateIdBeforeSend(lblCustomer, Customer."No.", '', Customer.SystemId);
            until Customer.Next() = 0;
    end;

    procedure PostAllInvoices()
    begin
        SalesInvHeader.Reset();
        if SalesInvHeader.FindSet() then
            repeat
                if SalesOrderFromCRM(SalesInvHeader."Order No.") then
                    EntityCRMOnUpdateIdBeforeSend(lblInvoice, SalesInvHeader."No.", '', SalesInvHeader.SystemId)
            until SalesInvHeader.Next() = 0;
    end;

    procedure PostAllPackages()
    begin
        PackageHeader.Reset();
        if PackageHeader.FindSet() then
            repeat
                if SalesOrderFromCRM(PackageHeader."Sales Order No.") then
                    EntityCRMOnUpdateIdBeforeSend(lblPackage, PackageHeader."No.", '', PackageHeader.SystemId)
            until PackageHeader.Next() = 0;
    end;

    local procedure SalesOrderFromCRM(OrderNo: Code[20]): Boolean
    var
        EntitySetup: Record "Entity Setup";
        locSH: Record "Sales Header";
        locSIH: Record "Sales Invoice Header";
    begin
        if not CheckEnableIntegrationCRM() then exit(false);

        EntitySetup.Get(lblInvoice);
        if not EntitySetup."Source CRM" then
            exit(true);

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

    procedure Guid2APIStr(_Guid: Guid): Text
    begin
        exit(Format(_Guid, 36, 4));
    end;

    procedure Date2APIStr(_Date: Date): Text
    begin
        exit(Format(_Date, 10, 9));
    end;

    procedure DateTime2APIStr(_Date: DateTime): Text
    begin
        exit(Format(_Date, 24, 9));
    end;

    local procedure InvoiceStatusCRMOnUpdateIdBeforeSend(entityType: Text[30]; Key1: Code[20]; Key2: Code[20]; IdBC: Guid)
    var
        locEntityCRM: Record "Entity CRM";
    begin
        if not locEntityCRM.Get(lblInvoice, Key1, '') or IsNullGuid(locEntityCRM."Id CRM") then exit;

        EntityCRMOnUpdateIdBeforeSend(entityType, Key1, '', IdBC);
        EntityCRMOnUpdateIdAfterSend(entityType, Key1, '', locEntityCRM."Id CRM", false);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Gen. Jnl.-Post Line", 'OnBeforePostDtldCVLedgEntry', '', false, false)]
    local procedure OnBeforePostDtldCVLedgEntry(var DetailedCVLedgEntryBuffer: Record "Detailed CV Ledg. Entry Buffer"; Unapply: Boolean)
    begin
        if Unapply then exit;
        if DetailedCVLedgEntryBuffer."CV Ledger Entry No." = DetailedCVLedgEntryBuffer."Applied CV Ledger Entry No." then exit;

        if not (CheckUnAppliedEntryPaymentOrInvoice(DetailedCVLedgEntryBuffer."CV Ledger Entry No.")
        and CheckUnAppliedEntryPaymentOrInvoice(DetailedCVLedgEntryBuffer."Applied CV Ledger Entry No.")) then
            exit;

        if not (isInvoiceFromCRM(DetailedCVLedgEntryBuffer."CV Ledger Entry No.")
        and isInvoiceFromCRM(DetailedCVLedgEntryBuffer."Applied CV Ledger Entry No.")) then
            exit;

        if isPayment(DetailedCVLedgEntryBuffer."Applied CV Ledger Entry No.") then
            CreateApplyTaskForSendingToCRM(DetailedCVLedgEntryBuffer."CV Ledger Entry No.", GetCustLedgEntrtyPostingDate(DetailedCVLedgEntryBuffer."CV Ledger Entry No."), GetCustLedgEntrtyDocumentNo(DetailedCVLedgEntryBuffer."CV Ledger Entry No."),
                                           DetailedCVLedgEntryBuffer."Applied CV Ledger Entry No.", GetCustLedgEntrtyPostingDate(DetailedCVLedgEntryBuffer."Applied CV Ledger Entry No."), GetCustLedgEntrtyDocumentNo(DetailedCVLedgEntryBuffer."Applied CV Ledger Entry No."),
                                           Abs(DetailedCVLedgEntryBuffer.Amount))
        else
            CreateApplyTaskForSendingToCRM(DetailedCVLedgEntryBuffer."Applied CV Ledger Entry No.", GetCustLedgEntrtyPostingDate(DetailedCVLedgEntryBuffer."Applied CV Ledger Entry No."), GetCustLedgEntrtyDocumentNo(DetailedCVLedgEntryBuffer."Applied CV Ledger Entry No."),
                                           DetailedCVLedgEntryBuffer."CV Ledger Entry No.", GetCustLedgEntrtyPostingDate(DetailedCVLedgEntryBuffer."CV Ledger Entry No."), GetCustLedgEntrtyDocumentNo(DetailedCVLedgEntryBuffer."CV Ledger Entry No."),
                                           Abs(DetailedCVLedgEntryBuffer.Amount));
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Gen. Jnl.-Post Line", 'OnBeforeInsertDtldCustLedgEntryUnapply', '', false, false)]
    local procedure OnBeforeInsertDtldCustLedgEntryUnapply(OldDtldCustLedgEntry: Record "Detailed Cust. Ledg. Entry")
    begin
        if OldDtldCustLedgEntry."Cust. Ledger Entry No." = OldDtldCustLedgEntry."Applied Cust. Ledger Entry No." then exit;

        if not (CheckUnAppliedEntryPaymentOrInvoice(OldDtldCustLedgEntry."Cust. Ledger Entry No.")
        and CheckUnAppliedEntryPaymentOrInvoice(OldDtldCustLedgEntry."Applied Cust. Ledger Entry No.")) then
            exit;

        if not (isInvoiceFromCRM(OldDtldCustLedgEntry."Cust. Ledger Entry No.")
                and isInvoiceFromCRM(OldDtldCustLedgEntry."Applied Cust. Ledger Entry No.")) then
            exit;

        if isPayment(OldDtldCustLedgEntry."Applied Cust. Ledger Entry No.") then
            CreateUnApplyTaskForSendingToCRM(OldDtldCustLedgEntry."Cust. Ledger Entry No.", GetCustLedgEntrtyPostingDate(OldDtldCustLedgEntry."Cust. Ledger Entry No."), GetCustLedgEntrtyDocumentNo(OldDtldCustLedgEntry."Cust. Ledger Entry No."),
                                             OldDtldCustLedgEntry."Applied Cust. Ledger Entry No.", GetCustLedgEntrtyPostingDate(OldDtldCustLedgEntry."Applied Cust. Ledger Entry No."), GetCustLedgEntrtyDocumentNo(OldDtldCustLedgEntry."Applied Cust. Ledger Entry No."),
                                             Abs(OldDtldCustLedgEntry.Amount))
        else
            CreateUnApplyTaskForSendingToCRM(OldDtldCustLedgEntry."Applied Cust. Ledger Entry No.", GetCustLedgEntrtyPostingDate(OldDtldCustLedgEntry."Applied Cust. Ledger Entry No."), GetCustLedgEntrtyDocumentNo(OldDtldCustLedgEntry."Applied Cust. Ledger Entry No."),
                                             OldDtldCustLedgEntry."Cust. Ledger Entry No.", GetCustLedgEntrtyPostingDate(OldDtldCustLedgEntry."Cust. Ledger Entry No."), GetCustLedgEntrtyDocumentNo(OldDtldCustLedgEntry."Cust. Ledger Entry No."),
                                             Abs(OldDtldCustLedgEntry.Amount));
    end;

    local procedure CheckUnAppliedEntryPaymentOrInvoice(EntryNo: Integer): Boolean
    var
        CustLedgEntry: Record "Cust. Ledger Entry";
    begin
        if CustLedgEntry.Get(EntryNo)
        and (CustLedgEntry."Document Type" in [CustLedgEntry."Document Type"::Invoice, CustLedgEntry."Document Type"::Payment]) then
            exit(true);
        exit(false);
    end;

    local procedure isInvoiceFromCRM(EntryNo: Integer): Boolean
    var
        CustLedgEntry: Record "Cust. Ledger Entry";
        SalesInvoiceHeader: Record "Sales Invoice Header";
    begin
        if CustLedgEntry.Get(EntryNo)
        and (CustLedgEntry."Document Type" in [CustLedgEntry."Document Type"::Invoice]) then begin
            if SalesInvoiceHeader.Get(CustLedgEntry."Document No.")
            and not IsNullGuid(SalesInvoiceHeader."CRM ID") then
                exit(true);
        end else
            exit(true);

        exit(false);
    end;

    local procedure isPayment(EntryNo: Integer): Boolean
    var
        CustLedgEntry: Record "Cust. Ledger Entry";
    begin
        if CustLedgEntry.Get(EntryNo)
        and (CustLedgEntry."Document Type" in [CustLedgEntry."Document Type"::Payment]) then
            exit(true);
        exit(false);
    end;

    local procedure GetCustLedgEntrtyPostingDate(EntryNo: Integer): Date
    var
        CustLedgEntry: Record "Cust. Ledger Entry";
    begin
        if CustLedgEntry.Get(EntryNo) then;
        exit(CustLedgEntry."Posting Date");
    end;

    local procedure GetCustLedgEntrtyDocumentNo(EntryNo: Integer): Code[20]
    var
        CustLedgEntry: Record "Cust. Ledger Entry";
    begin
        if CustLedgEntry.Get(EntryNo) then;
        exit(CustLedgEntry."Document No.");
    end;

    local procedure CreateApplyTaskForSendingToCRM(InvoiceEntryNo: Integer; InvoiceDate: Date; InvoiceNo: Code[20];
                                                   PaymentEntryNo: Integer; PaymentDate: Date; PaymentNo: Code[20];
                                                   PaymentAmount: Decimal);
    var
        locPaymentCRM: Record "Payment CRM";
    begin
        if locPaymentCRM.Get(InvoiceEntryNo, PaymentEntryNo, true) then begin
            locPaymentCRM.Amount := PaymentAmount;
            locPaymentCRM."Modify In CRM" := false;
            locPaymentCRM.Modify(true);
        end else begin
            locPaymentCRM.Init();
            locPaymentCRM.Apply := true;
            locPaymentCRM."Invoice Entry No." := InvoiceEntryNo;
            locPaymentCRM."Invoice Date" := InvoiceDate;
            locPaymentCRM."Invoice No." := InvoiceNo;
            locPaymentCRM."Payment Entry No." := PaymentEntryNo;
            locPaymentCRM."Payment Date" := PaymentDate;
            locPaymentCRM."Payment No." := PaymentNo;
            locPaymentCRM.Amount := PaymentAmount;
            locPaymentCRM."Id BC" := GetCLEIdDByEntry(PaymentEntryNo);
            locPaymentCRM.Insert(true);
        end;
    end;

    local procedure CreateUnApplyTaskForSendingToCRM(InvoiceEntryNo: Integer; InvoiceDate: Date; InvoiceNo: Code[20];
                                                     PaymentEntryNo: Integer; PaymentDate: Date; PaymentNo: Code[20];
                                                     PaymentAmount: Decimal)
    var
        locPaymentCRM: Record "Payment CRM";
    begin
        if locPaymentCRM.Get(InvoiceEntryNo, PaymentEntryNo, false) then begin
            locPaymentCRM.Amount := -PaymentAmount;
            locPaymentCRM."Id CRM" := GetApplyPaymentIdCRM(InvoiceEntryNo, PaymentEntryNo);
            locPaymentCRM."Modify In CRM" := IsNullGuid(locPaymentCRM."Id CRM");
            locPaymentCRM.Modify(true);
        end else begin
            locPaymentCRM.Init();
            locPaymentCRM."Invoice Entry No." := InvoiceEntryNo;
            locPaymentCRM."Invoice Date" := InvoiceDate;
            locPaymentCRM."Invoice No." := InvoiceNo;
            locPaymentCRM."Payment Entry No." := PaymentEntryNo;
            locPaymentCRM."Payment Date" := PaymentDate;
            locPaymentCRM."Payment No." := PaymentNo;
            locPaymentCRM.Amount := -PaymentAmount;
            locPaymentCRM."Id BC" := GetCLEIdDByEntry(PaymentEntryNo);
            locPaymentCRM."Id CRM" := GetApplyPaymentIdCRM(InvoiceEntryNo, PaymentEntryNo);
            locPaymentCRM."Modify In CRM" := IsNullGuid(locPaymentCRM."Id CRM");
            locPaymentCRM.Insert(true);
        end;
    end;

    local procedure GetCLEIdDByEntry(EntryNo: Integer): Guid
    var
        locCLE: Record "Cust. Ledger Entry";
    begin
        locCLE.Get(EntryNo);
        exit(locCLE.SystemId);
    end;

    local procedure GetApplyPaymentIdCRM(InvoiceEntryNo: Integer; PaymentEntryNo: Integer): Guid
    var
        AppliedPaymentCRM: Record "Payment CRM";
    begin
        if AppliedPaymentCRM.Get(InvoiceEntryNo, PaymentEntryNo, true) then
            if IsNullGuid(AppliedPaymentCRM."Id CRM") then begin
                AppliedPaymentCRM."Modify In CRM" := true;
                AppliedPaymentCRM.Modify(true);
            end;

        exit(AppliedPaymentCRM."Id CRM");
    end;

    local procedure InvoiceStatusUpdate(_entitytype: Text; _Key1: Code[20]; _Key2: Code[20]; _Open: Boolean)
    var
        locEntityCRM: Record "Entity CRM";
    begin
        if locEntityCRM.Get(_entitytype, _Key1, _Key2) then begin
            locEntityCRM."Invoice Open" := _Open;
            locEntityCRM.Modify(true);
        end;
    end;

    local procedure CheckItemFieldsFilled(ItemNo: Code[20]): Boolean
    begin
        if not Item.Get(EntityCRM.Key1)
        or not ItemDescr.Get(Item."No.")
        or (DelChr(Item.Description + Item."Description 2", '=', ' ') = '')
        or (DelChr(ItemDescr."Name ENG" + ItemDescr."Name ENG 2", '=', ' ') = '')
        or (DelChr(ItemDescr."Name RU" + ItemDescr."Name RU 2", '=', ' ') = '')
        or (DelChr(Blob2TextFromRec(Database::"Item Description", ItemDescr.RecordId, ItemDescr.FieldNo("Description RU")), '=', ' ') = '')
        or (DelChr(Blob2TextFromRec(Database::"Item Description", ItemDescr.RecordId, ItemDescr.FieldNo("Ingredients RU")), '=', ' ') = '')
        or (DelChr(Blob2TextFromRec(Database::"Item Description", ItemDescr.RecordId, ItemDescr.FieldNo("Indications RU")), '=', ' ') = '')
        or (DelChr(Blob2TextFromRec(Database::"Item Description", ItemDescr.RecordId, ItemDescr.FieldNo("Directions RU")), '=', ' ') = '')
        or (DelChr(Blob2TextFromRec(Database::"Item Description", ItemDescr.RecordId, ItemDescr.FieldNo(Warning)), '=', ' ') = '')
        or (DelChr(Blob2TextFromRec(Database::"Item Description", ItemDescr.RecordId, ItemDescr.FieldNo("Legal Disclaimer")), '=', ' ') = '')
        or (DelChr(Blob2TextFromRec(Database::"Item Description", ItemDescr.RecordId, ItemDescr.FieldNo(Description)), '=', ' ') = '')
        or (DelChr(Blob2TextFromRec(Database::"Item Description", ItemDescr.RecordId, ItemDescr.FieldNo(Ingredients)), '=', ' ') = '')
        or (DelChr(Blob2TextFromRec(Database::"Item Description", ItemDescr.RecordId, ItemDescr.FieldNo(Indications)), '=', ' ') = '')
        or (DelChr(Blob2TextFromRec(Database::"Item Description", ItemDescr.RecordId, ItemDescr.FieldNo(Directions)), '=', ' ') = '')
        or (Item."Unit Price" = 0) then
            exit(false);

        exit(true);
    end;

    local procedure GetOrderCRMId(InvoiceNo: Code[20]): Guid
    var
        locSIH: Record "Sales Invoice Header";
    begin
        locSIH.Get(InvoiceNo);
        exit(locSIH."CRM ID");
    end;

    local procedure GetCategoryId(ItemParentCategory: Code[20]): Guid
    var
        locItemCategory: Record "Item Category";
    begin
        if locItemCategory.Get(ItemParentCategory) then
            exit(locItemCategory.SystemId);
        exit(blankGuid);
    end;

    local procedure GetEntityRank(entityType: Text[30]; Key1: Code[20]): Integer
    var
        myInt: Integer;
    begin
        case entityType of
            lblItemCategory:
                exit(GetItemCategiryRank(Key1));
            else
                exit(0)
        end;
    end;

    local procedure GetItemCategiryRank(Key1: Code[20]): Integer
    var
        locItemCategory: Record "Item Category";
    begin
        locItemCategory.Get(Key1);
        exit(locItemCategory.Indentation);
    end;

    local procedure jsonGetFilterGroupArray(ItemNo: Code[20]): JsonArray
    var
        locItemFilterGroup: Record "Item Filter Group";
        oldItemFilterGroup: Text[50];
        jsonItemFilterGroupArray: JsonArray;
        jsonItemFilterGroup: JsonObject;
        jsonItemFilters: JsonArray;
    begin
        locItemFilterGroup.SetRange("Item No.", ItemNo);
        if locItemFilterGroup.FindSet() then
            repeat
                if oldItemFilterGroup <> locItemFilterGroup."Filter Group" then begin
                    jsonItemFilterGroup.Add('name_eng', locItemFilterGroup."Filter Group");
                    jsonItemFilterGroup.Add('name_ru', locItemFilterGroup."Filter Group RUS");
                    jsonItemFilterGroup.Add('filters_eng', AddItemFilterGroupENArray(locItemFilterGroup."Item No.", locItemFilterGroup."Filter Group"));
                    jsonItemFilterGroup.Add('filters_ru', AddItemFilterGroupRUArray(locItemFilterGroup."Item No.", locItemFilterGroup."Filter Group"));
                    jsonItemFilterGroupArray.Add(jsonItemFilterGroup);
                    jsonItemFilters.Add(jsonItemFilterGroup);
                    Clear(jsonItemFilterGroup);
                    oldItemFilterGroup := locItemFilterGroup."Filter Group";
                end;
            until locItemFilterGroup.Next() = 0;
        exit(jsonItemFilters);
    end;

    local procedure AddItemFilterGroupENArray(_ItemNo: Code[20]; _FilterGroup: Text[50]): JsonArray
    var
        _ItemFilterGroup: Record "Item Filter Group";
        _jsonItemFilterGroupArray: JsonArray;
    begin
        _ItemFilterGroup.SetRange("Item No.", _ItemNo);
        _ItemFilterGroup.SetRange("Filter Group", _FilterGroup);
        if _ItemFilterGroup.FindSet(false, false) then
            repeat
                _jsonItemFilterGroupArray.Add(_ItemFilterGroup."Filter Value");
            until _ItemFilterGroup.Next() = 0;
        exit(_jsonItemFilterGroupArray);
    end;

    local procedure AddItemFilterGroupRUArray(_ItemNo: Code[20]; _FilterGroup: Text[50]): JsonArray
    var
        _ItemFilterGroup: Record "Item Filter Group";
        _jsonItemFilterGroupArray: JsonArray;
    begin
        _ItemFilterGroup.SetRange("Item No.", _ItemNo);
        _ItemFilterGroup.SetRange("Filter Group", _FilterGroup);
        if _ItemFilterGroup.FindSet(false, false) then
            repeat
                _jsonItemFilterGroupArray.Add(_ItemFilterGroup."Filter Value RUS");
            until _ItemFilterGroup.Next() = 0;
        exit(_jsonItemFilterGroupArray);
    end;

    local procedure ItemFilterGroupExist(ItemNo: Code[20]): Boolean
    var
        ItemFilterGroup: Record "Item Filter Group";
    begin
        ItemFilterGroup.SetRange("Item No.", Item."No.");
        exit(ItemFilterGroup.FindFirst());
    end;

    local procedure GetSRSetup()
    begin
        if not SRSetup.Get() then begin
            SRSetup.Init();
            SRSetup.Insert();
        end;
    end;
}