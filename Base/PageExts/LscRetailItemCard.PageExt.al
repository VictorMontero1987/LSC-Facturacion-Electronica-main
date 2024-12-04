pageextension 36003105 "LSEF LSC Retail Item Card" extends "LSC Retail Item Card"
{

    var
        EfAdministrationSetup: Record "EF Administration Setup";
        SoapDocument: Codeunit "LSEF Soap Document";

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    begin
        if EfAdministrationSetup.Get() then
            if EfAdministrationSetup."LSEF Use Elec. Service On POS" then
                SoapDocument.ValidRetailItemForElectronic(Rec);

    end;
}