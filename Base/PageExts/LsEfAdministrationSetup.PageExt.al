pageextension 36003101 "LSEF Administration Setup" extends "EF Administration Setup"
{
    layout
    {
        addlast(General)
        {
            field("LSEF Use Elec. Service On POS"; Rec."LSEF Use Elec. Service On POS")
            {
                Caption = 'Use Electronic Service on POS';
                ToolTip = 'Activates Electronic Service on POS';
                ApplicationArea = All;
            }
            field("LSEF Print QR Code"; Rec."LSEF Print QR Code")
            {
                Caption = 'Print QR Code';
                ToolTip = 'Enabled POS to show QR Code on Receipt';
                ApplicationArea = All;
                trigger OnValidate()
                begin
                    IsPosPrinting := Rec."LSEF Print QR Code";
                end;
            }
            field("LSEF Def. NC Modification Type"; Rec."LSEF Def. NC Modification Type")
            {
                Caption = 'Def. NC Modification Type';
                ToolTip = 'Default NC Modification Code Type.';
                ApplicationArea = All;

            }

        }
        addlast(Content)
        {
            group(LsEfPrinting)
            {
                Caption = 'POS Printing';
                field("LSEF Barcode Width"; Rec."LSEF Barcode Width")
                {
                    ApplicationArea = All;
                    Enabled = IsPosPrinting;
                    Editable = IsPosPrinting;
                    Caption = 'QR Code Width';
                    ToolTip = 'QR Code Width to be printed on Receipt';
                }
                field("LSEF Barcode Height"; Rec."LSEF Barcode Height")
                {
                    ApplicationArea = All;
                    Enabled = IsPosPrinting;
                    Editable = IsPosPrinting;
                    Caption = 'QR Code Height';
                    ToolTip = 'QR Code Height to be printed on Receipt';
                }
            }
        }
    }

    actions
    {
        // Add changes to page actions here
    }

    var
        IsPosPrinting: Boolean;


    trigger OnOpenPage()
    begin
        if not Rec."LSEF Print QR Code" then begin
            Rec."LSEF Barcode Width" := 0;
            Rec."LSEF Barcode Height" := 0;
            IsPosPrinting := false;
        end else
            IsPosPrinting := true;

    end;

}