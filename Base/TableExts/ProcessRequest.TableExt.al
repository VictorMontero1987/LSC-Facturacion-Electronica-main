tableextension 36003105 LSEFProcessRequest extends "EF Process Request"
{
    fields
    {
        field(36003100; "LSEF Store No."; Code[10])
        {
            Caption = 'Store No.';
            TableRelation = "LSC Store"."No.";
            DataClassification = CustomerContent;
        }
        field(36003101; "LSEF POS Terminal No."; Code[10])
        {
            Caption = 'POS Terminal No.';
            TableRelation = "LSC POS Terminal"."No.";
            ValidateTableRelation = false;
            DataClassification = CustomerContent;
        }

        field(36003102; "LSEF Sent"; Boolean)
        {
            DataClassification = EndUserIdentifiableInformation;
        }
        field(36003103; "LSEF Replicated"; Date)
        {
            DataClassification = EndUserIdentifiableInformation;
        }
        field(36003104; "LSEF Replication Counter"; Integer)
        {
            DataClassification = EndUserIdentifiableInformation;
            Caption = 'Replication Counter';

            trigger OnValidate()
            var
                ProcessRequestList: Record "EF Process Request";
                ClientSessionUtility: Codeunit "LSC Client Session Utility";
            begin
                if not ClientSessionUtility.UpdateReplicationCounters() then
                    exit;
                ProcessRequestList.SetCurrentKey("LSEF Replication Counter");
                if ProcessRequestList.FindLast() then
                    "LSEF Replication Counter" := ProcessRequestList."LSEF Replication Counter" + 1
                else
                    "LSEF Replication Counter" := 1;
            end;
        }
        field(36003105; "LSEF Date"; Date)
        {
            DataClassification = EndUserIdentifiableInformation;
        }
    }

    keys
    {
        key(Key2; "LSEF Replicated", "LSEF Date")
        {
            Enabled = false;
        }
        key(Key3; "LSEF Replication Counter")
        {
        }
    }

    trigger OnInsert()
    begin
        Validate("LSEF Replication Counter");
    end;

    trigger OnModify()
    begin
        Validate("LSEF Replication Counter");
    end;
}
