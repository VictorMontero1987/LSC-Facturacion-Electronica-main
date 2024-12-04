pageextension 36003106 "LSEF Item Card" extends "Item Card"
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