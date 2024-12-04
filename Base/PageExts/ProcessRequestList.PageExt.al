pageextension 36003109 LSEFProcessRequestList extends "EF Process Request List"
{
    layout
    {
        addfirst(Control1)
        {

            field("LSEF Source Code Type"; Rec."EF Source Code Type")
            {
                ApplicationArea = All;
                Caption = 'Source Code';
                ToolTip = 'Specifies the value of the EF Source Code Type field.';
            }
        }
        addlast(Control1)
        {
            field("LSEF Store No."; Rec."LSEF Store No.")
            {
                ApplicationArea = All;
                Caption = 'Store No.';
                ToolTip = 'Store No.';
            }
            field("LSEF POS Terminal No."; Rec."LSEF POS Terminal No.")
            {
                ApplicationArea = All;
                Caption = 'POS Terminal No.';
                ToolTip = 'POS Terminal No.';
            }

            field("LSEF Date"; Rec."LSEF Date")
            {
                ApplicationArea = All;
                Caption = 'Date';
                ToolTip = 'Date';
            }

            field("LSEF Replication Counter"; Rec."LSEF Replication Counter")
            {
                ApplicationArea = All;
                Caption = 'Replication Counter';
                ToolTip = 'Replication Counter';
            }
        }
    }
}
