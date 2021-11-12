page 50071 "Entity CRM List"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "Entity CRM";
    SourceTableView = sorting(Code) order(descending);
    AccessByPermission = tabledata "Entity CRM" = rimd;

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
                field("Modify In CRM"; Rec."Modify In CRM")
                {
                    ApplicationArea = All;

                }
                field("No. of Attempts to Run"; Rec."No. of Attempts to Run")
                {
                    ApplicationArea = All;

                }
                field(Key1; Rec.Key1)
                {
                    ApplicationArea = All;

                }
                field(Key2; Rec.Key2)
                {
                    ApplicationArea = All;

                }
                field("Id CRM"; Rec."Id CRM")
                {
                    ApplicationArea = All;

                }
                field("Id BC"; Rec."Id BC")
                {
                    ApplicationArea = All;

                }
                field("Create User ID"; Rec."Create User ID")
                {
                    ApplicationArea = All;

                }
                field("Create Date Time"; Rec."Create Date Time")
                {
                    ApplicationArea = All;

                }
                field("Modify User ID"; Rec."Modify User ID")
                {
                    ApplicationArea = All;

                }
                field("Modify Date Time"; Rec."Modify Date Time")
                {
                    ApplicationArea = All;

                }
                field("Payment Amount"; Rec."Payment Amount")
                {
                    ApplicationArea = All;

                }
                field("Invoice Open"; Rec."Invoice Open")
                {
                    ApplicationArea = All;

                }
                field(Rank; Rec.Rank)
                {
                    ApplicationArea = All;

                }
            }
        }
    }
}