pageextension 36003107 "LSEF Tender Type Relation" extends "LSDXTender Types Relation"
{
    layout
    {
        addlast(Group)
        {
            field("LSEF Payment Type"; Rec."LSEF Payment Type")
            {
                ApplicationArea = All;
                Caption = 'LS EF Payment Type';
                ToolTip = 'LS EF Payment Type';
            }
            field("LSEF Payment Type Form"; Rec."LSEF Payment Type Form")
            {
                ApplicationArea = All;
                Caption = 'LS EF Payment Type Form';
                ToolTip = 'LS EF Payment Type Form';
            }
        }
    }

}