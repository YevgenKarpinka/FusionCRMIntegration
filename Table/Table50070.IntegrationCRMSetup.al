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
            TableRelation = "Entity Setup";
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
            CaptionML = ENU = 'Parameters',
                        RUS = 'Параметр';
        }
        field(4; Production; Boolean)
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'Production',
                        RUS = 'Прод.';
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