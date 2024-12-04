tableextension 36003101 "LSEF LSC Transaction Header" extends "LSC Transaction Header"
{
    fields
    {
        field(36003100; "LSEF Applies for ISC"; Boolean)
        {
            DataClassification = EndUserIdentifiableInformation;
            Caption = 'Applies for ISC';
        }
        field(36003101; "LSEF Signature Value"; Blob)
        {
            DataClassification = EndUserIdentifiableInformation;
            Caption = 'Signature Value';
        }
        field(36003102; "LSEF NCF Modification Reason"; Integer)
        {
            DataClassification = EndUserIdentifiableInformation;
            Caption = 'NCF Modification Reason';
            TableRelation = "EF Modification Code Type";
        }
        field(36003103; "LSEF e-NCF Type"; Enum "EF eCFType")
        {
            DataClassification = EndUserIdentifiableInformation;
            Caption = 'e-NCF Type';
        }
        field(36003105; "LSEF Stamped Date/Time"; Text[20])
        {
            DataClassification = EndUserIdentifiableInformation;
            Caption = 'Stamped Date/Time';
        }
        field(36003106; "LSEF Alternal NCF Serial No."; Code[20])
        {
            Caption = 'Alternal NCF Serial No.';
            DataClassification = CustomerContent;
            TableRelation = "No. Series";
        }
        field(36003107; "LSEF Alternal NCF"; Code[20])
        {
            Caption = 'Alternal NCF';
            DataClassification = CustomerContent;
            TableRelation = "No. Series";
            trigger OnValidate()
            begin
                Rec."LSEF Has Contingencies" := Rec."LSEF Alternal NCF" <> '';
            end;
        }
        field(36003108; "LSEF Has Contingencies"; Boolean)
        {
            Editable = false;
            Caption = 'Has Contingencies';
            DataClassification = CustomerContent;
        }
        field(36003109; "LSEF Security Code"; Text[6])
        {
            DataClassification = CustomerContent;
            Caption = 'Security Code';
        }
        field(36003110; "LSEF Encoded Barcode"; Blob)
        {
            DataClassification = CustomerContent;
            Caption = 'Barcode Image';
        }
        field(36003111; LSEfQRImage; Media)
        {
            DataClassification = CustomerContent;
            Caption = 'QR Image';
        }


    }

}