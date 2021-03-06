table 50071 "Entity CRM"
{
    DataClassification = CustomerContent;
    CaptionML = ENU = 'Entity to CRM"',
                RUS = 'Сущности для CRM';

    fields
    {
        field(1; Code; Code[30])
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'Code',
                        RUS = 'Код';
            TableRelation = "Entity Setup";
        }
        field(2; Key1; Code[20])
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'Key 1',
                        RUS = 'Ключ 1';
        }
        field(3; Key2; Code[20])
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'Key 2',
                        RUS = 'Ключ 2';
        }
        field(4; "Create Date Time"; DateTime)
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'Create Date Time',
                        RUS = 'Дата и время создания';
        }
        field(5; "Modify Date Time"; DateTime)
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'Modify Date Time',
                        RUS = 'Дата и время модификации';
        }
        field(6; "Create User ID"; Code[50])
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'Create User ID',
                        RUS = 'Создал пользователь ИД';
        }
        field(7; "Modify User ID"; Code[50])
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'Modify User ID',
                        RUS = 'Модифицировал пользователь ИД';
        }
        field(8; "Modify In CRM"; Boolean)
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'Modify In CRM',
                        RUS = 'Модифицировано в CRM';
        }
        field(9; "Id CRM"; Guid)
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'Id CRM',
                        RUS = 'ИД CRM';
        }
        field(10; "Id BC"; Guid)
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'Id BC',
                        RUS = 'ИД BC';
        }
        field(11; "Payment Amount"; Decimal)
        {
            CaptionML = ENU = 'Payment Amount',
                        RUS = 'Сумма платежа';
            FieldClass = FlowField;
            CalcFormula = sum("Payment CRM".Amount where("Invoice No." = field(Key1)));
            Editable = false;
        }
        field(12; "Invoice Open"; Boolean)
        {
            CaptionML = ENU = 'Invoice Open',
                        RUS = 'Открытый счёт';
            DataClassification = CustomerContent;
        }
        field(13; Rank; Integer)
        {
            CaptionML = ENU = 'Rank',
                        RUS = 'Приоритет';
            DataClassification = CustomerContent;
        }
        field(14; "No. of Attempts to Run"; Integer)
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'No. of Attempts to Run',
                        RUS = 'Кол-во попыток запуска';
        }
    }

    keys
    {
        key(Key1; Code, Key1, Key2)
        {
            Clustered = true;
        }
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
}