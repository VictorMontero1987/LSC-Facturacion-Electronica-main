pageextension 36003110 LSEFLSCTransactionCard extends "LSC Transaction Card"
{

    layout
    {
        addfirst(factboxes)
        {
            part(LSEfQRcode; "LSEFQRCode")
            {
                ApplicationArea = All;
                SubPageLink = "Receipt No." = field("Receipt No.");
                Caption = 'Signature Barcode';
                Visible = NonVisibleForElectronic;
            }
        }

        addlast(LSDXFiscalData)
        {
            group(LSEFElectronicFiscalData)
            {
                Caption = 'Electronic Fiscal Data';


                field("LSEF Security Code"; Rec."LSEF Security Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Security Code field.';
                }

                field("LSEF Stamped Date/Time"; Rec."LSEF Stamped Date/Time")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Stamped Date/Time field.';
                }
                field("LSEF Has Contingencies"; Rec."LSEF Has Contingencies")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Has Contingencies field.';
                }
                field("LSEF Alternal NCF Serial No."; Rec."LSEF Alternal NCF Serial No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Alternal NCF Serial No. field.';
                }
                field("LSEF Alternal NCF"; Rec."LSEF Alternal NCF")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Alternal NCF field.';
                }
                field("LSEF NCF Modification Reason"; Rec."LSEF NCF Modification Reason")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the NCF Modification Reason field.';
                }
            }
        }
    }
    var
        EFUtilityManagement: codeunit "EF Utility Management";
        LSEFElectronicPOSUtility: Codeunit "LSEF Electronic POS Utility";
        NonVisibleForElectronic: Boolean;

    trigger OnAfterGetCurrRecord()
    begin
        if NonVisibleForElectronic then
            LSEFElectronicPOSUtility.InitQRArguments(Rec);
    end;


    trigger OnOpenPage()
    begin
        NonVisibleForElectronic := (Rec."LSDX NCF" <> '');
        NonVisibleForElectronic := NonVisibleForElectronic AND EFUtilityManagement.IsValidElectronicNCF(Rec."LSDX NCF");
    end;
}
