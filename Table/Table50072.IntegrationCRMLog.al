table 50072 "Integration CRM Log"
{
    DataClassification = ToBeClassified;
    DataPerCompany = false;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            DataClassification = CustomerContent;
            // AutoIncrement = true;
            CaptionML = ENU = 'Entry No.', RUS = 'Операция Но.';
            Editable = false;
        }
        field(2; "Operation Date"; DateTime)
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'Operation Date', RUS = 'Дата операции';
        }
        field(3; "Source Operation"; Code[20])
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'Source Operation', RUS = 'Источник операции';
        }
        field(4; Success; Boolean)
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'Success', RUS = 'Успех';
        }
        field(5; Request; Blob)
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'Request', RUS = 'Запрос';
        }
        field(6; Response; Blob)
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'Response', RUS = 'Ответ';
        }
        field(7; "Rest Method"; Code[10])
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'Success', RUS = 'Успех';
        }
        field(8; URL; Text[250])
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'URL', RUS = 'Запрос';
        }
        field(9; Autorization; Text[250])
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'Autorization', RUS = 'Авторизация';
        }
        field(10; "Company Name"; Text[30])
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'Company Name', RUS = 'Имя компании';
        }
        field(11; "User Id"; Text[50])
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'User Id', RUS = 'ИД пользователя';
        }
        field(12; "Full Name"; Text[80])
        {
            CaptionML = ENU = 'Full Name', RUS = 'Имя пользователя';
            FieldClass = FlowField;
            CalcFormula = Lookup(User."Full Name" where("User Name" = field("User Id")));
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(SK; "Source Operation", Success)
        { }
    }

    var
        Window: Dialog;
        IntegrtionCRM: Codeunit "Integration CRM";
        ConfirmDeletingEntriesQst: TextConst ENU = 'Are you sure that you want to delete job queue log entries?',
                                            RUS = 'Вы действительно хотите удалить записи журнала очереди работ?';
        DeletingMsg: TextConst ENU = 'Deleting Entries...',
                                RUS = 'Удаление операций...';
        DeletedMsg: TextConst ENU = 'Entries have been deleted.',
                                RUS = 'Операции удалены.';

    procedure SetRequest(NewRequest: Text)
    var
        OutStream: OutStream;
    begin
        Clear(Request);
        Request.CreateOutStream(OutStream, TEXTENCODING::UTF8);
        OutStream.WriteText(NewRequest);
        Modify();
    end;

    procedure GetRequest(): Text
    var
        TypeHelper: Codeunit "Type Helper";
        InStream: InStream;
    begin
        CalcFields(Request);
        Request.CreateInStream(InStream, TEXTENCODING::UTF8);
        exit(TypeHelper.ReadAsTextWithSeparator(InStream, TypeHelper.LFSeparator));
    end;

    procedure SetResponse(NewResponse: Text)
    var
        OutStream: OutStream;
    begin
        Clear(Response);
        Response.CreateOutStream(OutStream, TEXTENCODING::UTF8);
        OutStream.WriteText(NewResponse);
        Modify();
    end;

    procedure GetResponse(): Text
    var
        TypeHelper: Codeunit "Type Helper";
        InStream: InStream;
    begin
        CalcFields(Response);
        Response.CreateInStream(InStream, TEXTENCODING::UTF8);
        exit(TypeHelper.ReadAsTextWithSeparator(InStream, TypeHelper.LFSeparator));
    end;

    procedure InsertOperationToLog(Source: Code[20]; RestMethod: Code[10]; _URL: Text; _Autorization: Text; _Request: Text; _Response: Text)
    var
        LastEntryNo: Integer;
        isError: Boolean;
        jaResponse: JsonArray;
        jtResponse: JsonToken;
        jaRequest: JsonArray;
        jtRequest: JsonToken;
        locResponse: Text;
        locRequest: Text;
    begin
        jaResponse.ReadFrom(_Response);
        jaRequest.ReadFrom(_Request);
        foreach jtResponse in jaResponse do begin
            isError := IntegrtionCRM.GetJSToken(jtResponse.AsObject(), 'error').AsValue().AsBoolean();
            jtResponse.WriteTo(locResponse);

            jaRequest.Get(jaResponse.IndexOf(jtResponse), jtRequest);
            jtRequest.WriteTo(locRequest);

            LastEntryNo := GetLastEntryNo();
            Init();
            "Entry No." := LastEntryNo + 1;
            "Operation Date" := CurrentDateTime;
            "Source Operation" := Source;
            Autorization := CopyStr(_Autorization, 1, MaxStrLen(Autorization));
            "Rest Method" := RestMethod;
            URL := _URL;
            Success := not isError;
            "Company Name" := CompanyName;
            "User Id" := UserId;
            Insert();
            SetRequest(locRequest);
            SetResponse(locResponse);

        end;
        Commit();
    end;

    local procedure GetLastEntryNo(): Integer
    var
        LastIntegrationCRMLog: Record "Integration CRM Log";
    begin
        LastIntegrationCRMLog.LockTable();
        if LastIntegrationCRMLog.FindLast() then
            exit(LastIntegrationCRMLog."Entry No.");
        exit(0);
    end;

    procedure DeleteEntries(DaysOld: Integer)
    begin
        if GuiAllowed then
            if not Confirm(ConfirmDeletingEntriesQst) then
                exit;
        Window.Open(DeletingMsg);
        // SetRange(Status, Status::"In Process");
        IF DaysOld > 0 THEN
            SetFilter("Operation Date", '<=%1', CreateDateTime(Today - DaysOld, Time));
        DeleteAll();
        Window.Close;
        SetRange("Operation Date");
        // SetRange(Status);
        Message(DeletedMsg);
    end;
}