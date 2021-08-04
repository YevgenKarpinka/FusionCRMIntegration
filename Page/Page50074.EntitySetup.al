page 50074 "Entity Setup"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "Entity Setup";
    SourceTableView = sorting(Rank);
    AccessByPermission = tabledata "Entity Setup" = rimd;

    layout
    {
        area(Content)
        {
            repeater(RepeaterName)
            {
                field(Code; Rec.Code)
                {
                    ApplicationArea = All;

                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;

                }
                field(Rank; Rec.Rank)
                {
                    ApplicationArea = All;

                }
                field("Source CRM"; Rec."Source CRM")
                {
                    ApplicationArea = All;

                }
                field("Request To File"; Rec."Request To File")
                {
                    ApplicationArea = All;

                }

            }
        }
    }

    actions
    {
        // area(Processing)
        // {
        //     action(EntityCRM)
        //     {
        //         CaptionML = ENU = 'Entity CRM',
        //                     RUS = 'Сущности CRM';
        //         ApplicationArea = All;
        //         RunObject = Page "Entity CRM List";
        //         RunPageMode = View;
        //     }
        // }
    }

}