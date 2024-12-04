tableextension 36003100 "LSEF LSC Trans. Sales Entry" extends "LSC Trans. Sales Entry"
{
    fields
    {
        field(36003100; "LSEF Applies for ISC"; Boolean)
        {
            DataClassification = EndUserIdentifiableInformation;
            Caption = 'Applies for ISC';
        }
        field(36003102; "LSEF Tax Indicator"; Enum "EF Invoice Tax Indicator Type")
        {
            DataClassification = EndUserIdentifiableInformation;
            Caption = 'Electronic Tax Indicator';
        }

        field(36003103; "LSEF Applies for Withholding"; Boolean)
        {
            DataClassification = EndUserIdentifiableInformation;
            Caption = 'Applies for Withholding';
        }
        field(36003104; "LSEF UOM Type"; Code[2])
        {
            DataClassification = EndUserIdentifiableInformation;
            Caption = 'UOM Type';
            TableRelation = "EF Unit of Measure Type";
        }
    }

}