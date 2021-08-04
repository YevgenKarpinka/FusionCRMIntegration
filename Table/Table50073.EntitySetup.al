table 50073 "Entity Setup"
{
    DataClassification = CustomerContent;
    CaptionML = ENU = 'Entity Setup"',
                RUS = 'Настройка сущности';

    fields
    {
        field(1; Code; Code[30])
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'Code',
                        RUS = 'Код';
        }
        field(2; Rank; Integer)
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'Rank',
                        RUS = 'Рейтинг';
        }
        field(3; Description; Text[50])
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'Description',
                        RUS = 'Описание';
        }
        field(4; "Source CRM"; Boolean)
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'Source CRM',
                        RUS = 'Источник CRM';
        }
        field(5; "Request To File"; Boolean)
        {
            DataClassification = CustomerContent;
            CaptionML = ENU = 'Request To File',
                        RUS = 'Запрос в файл';
        }
    }

    keys
    {
        key(Key1; Code)
        {
            Clustered = true;
        }
        key(skey1; Rank)
        {
        }
    }

}