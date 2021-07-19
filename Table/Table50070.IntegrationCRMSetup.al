table 50070 "Integration CRM Setup"
{
    DataClassification = CustomerContent;
    CaptionML = ENU = 'Integration CRM Setup',
                RUS = 'Настройка интеграции с CRM';

    fields
    {
        field(1; Code; Code[30])
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'Code',
                        RUS = 'Код';
        }
        field(2; URL; Text[200])
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'URL',
                        RUS = 'Веб адрес';
        }
        field(3; Param; Text[100])
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'Param',
                        RUS = 'Параметр';
        }
    }

    keys
    {
        key(Key1; Code)
        {
            Clustered = true;
        }
    }
}