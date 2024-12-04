pageextension 36003103 "LSEF Customer Card" extends "Customer Card"
{
    var
        EfAdministrationSetup: Record "EF Administration Setup";
        SoapDocument: Codeunit "LSEF Soap Document";

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    begin
        if EfAdministrationSetup.Get() and EfAdministrationSetup."LSEF Use Elec. Service On POS" then
            SoapDocument.ValidElectronicCustomer(Rec);
    end;

}