pageextension 36003102 "LSEF PosTerminal Card" extends "LSC POS Terminal Card"
{
    layout
    {
        addlast(LSDXNoSeries)
        {
            group(LSEFAlternalNCFNoSeries)
            {
                Caption = 'Series No. Contingencies - eCf';
                field("LSEF Alternal NCF Serial No."; Rec."LSEF Alternal NCF SerialNo CRF")
                {
                    ApplicationArea = All;
                    Caption = 'Alternal NCF Serial No. CRF';
                    ToolTip = 'Alternal NCF Serial No. CRF';
                    Visible = gVisible;
                    Editable = gVisible;
                }
                field("LSEF Alternal NCF Serial No. CF"; Rec."LSEF Alternal NCF SerialNo CF")
                {
                    ApplicationArea = All;
                    Caption = 'Alternal NCF Serial No. CF';
                    ToolTip = 'Alternal NCF Serial No. CF';
                    Visible = gVisible;
                    Editable = gVisible;
                }
                field("LSEF Alternal NCF Serial No. ESP"; Rec."LSEF Alternal NCF SerialNo ESP")
                {
                    ApplicationArea = All;
                    Caption = 'Alternal NCF Serial No. ESP';
                    ToolTip = 'Alternal NCF Serial No. ESP';
                    Visible = gVisible;
                    Editable = gVisible;
                }
                field("LSEF Alternal NCF Serial No. GUB"; Rec."LSEF Alternal NCF SerialNo GUB")
                {
                    ApplicationArea = All;
                    Caption = 'Alternal NCF Serial No. GUB';
                    ToolTip = 'Alternal NCF Serial No. GUB';
                    Visible = gVisible;
                    Editable = gVisible;
                }
                field("LSEF Alternal NCF Serial No. NC"; Rec."LSEF Alternal NCF SerialNo NC")
                {
                    ApplicationArea = All;
                    Caption = 'Alternal NCF Serial No. NC';
                    ToolTip = 'Alternal NCF Serial No. NC';
                    Visible = gVisible;
                    Editable = gVisible;
                }
            }
        }
    }

    var
        EfAdministrationSetup: Record "EF Administration Setup";
        gVisible: Boolean;

    trigger OnOpenPage()
    begin
        gVisible := EfAdministrationSetup.Get() and EfAdministrationSetup."LSEF Use Elec. Service On POS";
    end;

}