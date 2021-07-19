page 50072 "Integration CRM Log List"
{
    CaptionML = ENU = 'Integration CRM Log List',
                RUS = 'Список операций интеграции CRM';
    InsertAllowed = false;
    SourceTable = "Integration CRM Log";
    CardPageId = "Integration CRM Log Card";
    SourceTableView = sorting("Entry No.") order(Descending);
    DataCaptionFields = "Entry No.", "Source Operation";
    ApplicationArea = All;
    Editable = false;
    PageType = List;
    UsageCategory = History;
    AccessByPermission = tabledata "Integration CRM Log" = r;

    layout
    {
        area(Content)
        {
            repeater(RepeaterName)
            {
                Editable = false;
                field("Entry No."; Rec."Entry No.")
                {
                    ApplicationArea = All;

                }
                field("Operation Date"; Rec."Operation Date")
                {
                    ApplicationArea = All;

                }
                field("Source Operation"; Rec."Source Operation")
                {
                    ApplicationArea = All;

                }
                field("Operation Status"; Rec.Success)
                {
                    ApplicationArea = All;

                }
                field("Company Name"; Rec."Company Name")
                {
                    ApplicationArea = All;

                }
                field("User Id"; Rec."User Id")
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
            group(DeleteEntries)
            {
                CaptionML = ENU = 'Delete Entries',
                            RUS = 'Удалить операции';
                action(DeleteSevenDaysOld)
                {
                    ApplicationArea = All;
                    CaptionML = ENU = 'Delete 7 Days Old',
                                RUS = 'Удалить старше 7ми дней';

                    trigger OnAction()
                    begin
                        Rec.DeleteEntries(7);
                    end;
                }
                action(DeleteAll)
                {
                    ApplicationArea = All;
                    CaptionML = ENU = 'Delete All',
                                RUS = 'Удалить все';

                    trigger OnAction()
                    begin
                        Rec.DeleteEntries(0);
                    end;
                }
            }
        }
    }
}