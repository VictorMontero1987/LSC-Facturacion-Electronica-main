tableextension 36003102 "LSEF LSDX Tender Type Relation" extends "LSDXTender Types Relation"
{
    fields
    {
        field(36003100; "LSEF Payment Type"; Enum "EF Payment Type")
        {
            DataClassification = EndUserIdentifiableInformation;
            Caption = 'EF Payment Type';
        }
        field(36003101; "LSEF Payment Type Form"; Code[10])
        {
            DataClassification = EndUserIdentifiableInformation;
            Caption = 'EF Payment Type Form';
            TableRelation = "EF Payment Type Form";
        }
    }
}