page 50070 "Integration CRM Setup"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "Integration CRM Setup";
    SourceTableView = sorting(Code) order(descending);
    AccessByPermission = tabledata "Integration CRM Setup" = rimd;

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
                field(URL; Rec.URL)
                {
                    ApplicationArea = All;

                }
                field(Param; Rec.Param)
                {
                    ApplicationArea = All;

                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ActionName)
            {
                ApplicationArea = All;

                trigger OnAction()
                begin

                end;
            }
        }
    }

    var
        myInt: Integer;
}