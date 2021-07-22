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
    }

    keys
    {
        key(Key1; Code)
        {
            Clustered = true;
        }
    }

}