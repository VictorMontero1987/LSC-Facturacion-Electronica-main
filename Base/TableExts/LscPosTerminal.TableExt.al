tableextension 36003104 "LSEF LSC POS Terminal" extends "LSC POS Terminal"
{
    fields
    {
        field(36003100; "LSEF Alternal NCF SerialNo CRF"; Code[20])
        {
            DataClassification = CustomerContent;
            TableRelation = "No. Series";
        }
        field(36003101; "LSEF Alternal NCF SerialNo CF"; Code[20])
        {
            DataClassification = CustomerContent;
            TableRelation = "No. Series";
        }
        field(36003102; "LSEF Alternal NCF SerialNo ESP"; Code[20])
        {
            DataClassification = CustomerContent;
            TableRelation = "No. Series";
        }
        field(36003103; "LSEF Alternal NCF SerialNo GUB"; Code[20])
        {
            DataClassification = CustomerContent;
            TableRelation = "No. Series";
        }

        field(36003104; "LSEF Alternal NCF SerialNo NC"; Code[20])
        {
            DataClassification = CustomerContent;
            TableRelation = "No. Series";
        }
    }
}