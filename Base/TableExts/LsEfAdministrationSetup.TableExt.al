tableextension 36003103 "LSEF Administration Setup" extends "EF Administration Setup"
{
    fields
    {
        field(36003100; "LSEF Use Elec. Service On POS"; Boolean)
        {
            DataClassification = CustomerContent;
            Caption = 'Use Electronic Service On POS';
            trigger OnValidate()
            var
                DxNcfSetup: Record "DXNCF Setup";
            begin
                DxNcfSetup.Get();
                DxNcfSetup.TestField("Funcionalidad e-CF", true);
            end;
        }
        field(36003101; "LSEF Send Request From POS"; Boolean)
        {
            DataClassification = CustomerContent;
            Caption = 'Send Request From POS';
        }
        field(36003102; "LSEF Barcode Width"; Integer)
        {
            Caption = 'Receipt Barcode Width';
            DataClassification = CustomerContent;
        }
        field(36003103; "LSEF Barcode Height"; Integer)
        {
            Caption = 'Receipt Barcode Height';
            DataClassification = CustomerContent;
        }
        field(36003104; "LSEF Print QR Code"; Boolean)
        {
            Caption = 'Print QR Code';
            DataClassification = CustomerContent;
        }
        field(36003105; "LSEF Def. NC Modification Type"; Integer)
        {
            Caption = 'Default NC Modification Type';
            DataClassification = CustomerContent;
            TableRelation = "EF Modification Code Type";
        }
    }

}