table 50074 "Payment CRM"
{
    DataClassification = SystemMetadata;
    DrillDownPageID = "Payment CRM";
    LookupPageID = "Payment CRM";

    fields
    {
        field(1; "Invoice Entry No."; Integer)
        {
            CaptionML = ENU = 'Invoice Entry No.',
                        RUS = 'Номер операции счета';
            DataClassification = CustomerContent;
        }
        field(2; "Payment Entry No."; Integer)
        {
            CaptionML = ENU = 'Payment Entry No.',
                        RUS = 'Номер операции платежа';
            DataClassification = CustomerContent;
        }
        field(3; "Modify In CRM"; Boolean)
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'Modify In CRM',
                        RUS = 'Модифицировано в CRM';
        }
        field(4; "Amount"; Decimal)
        {
            CaptionML = ENU = 'Payment Amount',
                        RUS = 'Сумма платежа';
            DataClassification = CustomerContent;
        }
        field(5; "Invoice No."; Code[20])
        {
            CaptionML = ENU = 'Invoice No.',
                        RUS = 'Номер счета';
            DataClassification = CustomerContent;
        }
        field(6; "Invoice Date"; Date)
        {
            CaptionML = ENU = 'Invoice Date',
                        RUS = 'Дата счета';
            DataClassification = CustomerContent;
        }
        field(7; "Payment No."; Code[20])
        {
            CaptionML = ENU = 'Payment No.',
                        RUS = 'Номер платежа';
            DataClassification = CustomerContent;
        }
        field(8; "Payment Date"; Date)
        {
            CaptionML = ENU = 'Payment Date',
                        RUS = 'Дата платежа';
            DataClassification = CustomerContent;
        }

        field(9; "Id CRM"; Guid)
        {
            CaptionML = ENU = 'Id CRM',
                        RUS = 'ИД CRM';
            DataClassification = CustomerContent;
        }
        field(10; "Id BC"; Guid)
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'Id BC',
                        RUS = 'ИД BC';
        }
        field(11; "Create User ID"; Code[50])
        {
            CaptionML = ENU = 'Create User ID',
                        RUS = 'ИД пользователя создания';
            DataClassification = CustomerContent;
        }
        field(12; "Create Date Time"; DateTime)
        {
            CaptionML = ENU = 'Create Date Time',
                        RUS = 'Дата и время создания';
            DataClassification = CustomerContent;
        }
        field(13; "Modify User ID"; Code[50])
        {
            CaptionML = ENU = 'Modify User ID',
                        RUS = 'ИД пользователя модификации';
            DataClassification = CustomerContent;
        }
        field(14; "Modify Date Time"; DateTime)
        {
            CaptionML = ENU = 'Modify Date Time',
                        RUS = 'Дата и время модификации';
            DataClassification = CustomerContent;
        }
        field(15; Apply; Boolean)
        {
            CaptionML = ENU = 'Apply',
                        RUS = 'Применение';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Invoice Entry No.", "Payment Entry No.", Apply)
        {
            Clustered = true;
        }
        key(SK; "Invoice No.", "Payment No.") { }
        key(SK1; "Create Date Time") { }
    }

    trigger OnInsert()
    begin
        "Create User ID" := UserId;
        "Create Date Time" := CurrentDateTime;
    end;

    trigger OnModify()
    begin
        "Modify User ID" := UserId;
        "Modify Date Time" := CurrentDateTime;
    end;

    trigger OnDelete()
    begin

    end;

    trigger OnRename()
    begin

    end;

    var
        Window: Dialog;
        ConfirmDeletingEntriesQst: TextConst ENU = 'Are you sure that you want to delete job queue log entries?',
                                            RUS = 'Вы действительно хотите удалить записи журнала очереди работ?';
        DeletingMsg: TextConst ENU = 'Deleting Entries...',
                                RUS = 'Удаление операций...';
        DeletedMsg: TextConst ENU = 'Entries have been deleted.',
                                RUS = 'Операции удалены.';
}