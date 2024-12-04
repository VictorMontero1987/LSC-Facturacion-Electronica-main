pageextension 36003108 "Lsef Retail Vendor Card" extends "LSC Retail Vendor Card"
{
    layout
    {
        // Add changes to page layout here
        modify("VAT Registration No.")
        {
            ShowMandatory = true;
            Importance = Promoted;
        }

        modify("E-Mail")
        {
            ShowMandatory = true;
            Importance = Promoted;
        }
        modify("Phone No.")
        {
            ShowMandatory = true;
            Importance = Promoted;
        }
        modify("Post Code")
        {
            ShowMandatory = true;
            Importance = Promoted;
        }
        addafter("Post Code")
        {
            field("LSEF DR Township Code"; Rec."EF DR Township Code")
            {
                Caption = 'DR Township Code';
                ToolTip = 'Township Code for DR';
                ApplicationArea = All;
                ShowMandatory = true;
                Importance = Promoted;
                Style = Attention;

            }
            field("LSEF DR County Code"; Rec."EF DR County Code")
            {
                Caption = 'DR County Code';
                ToolTip = 'County Code for DR';
                ApplicationArea = All;
                ShowMandatory = true;
                Importance = Promoted;
                Style = Attention;
            }
        }
    }

    trigger OnOpenPage()
    var
        EfAdministrationSetup: Record "EF Administration Setup";
        CountyNotification: Notification;
        TwonshipNotification: Notification;
        EmailNotification: Notification;
        CRLF: Text[2];
        MessageText: Text;
        notificationLbl: Label ' %1 should have a value on %2 table for Electronic Service to work properly', Comment = '%1 Field Caption for Customer Table, %2 = Table Caption for Customer Table';
        notificationHeaderLbl: Label 'Electronic Service Notification';
        notificationCaptionLbl: Label ' Notification %1:', Comment = '%1 = Notification Number';
    begin
        // TODO: VALIDAR SI ESTE CODIGO SE PUEDE MOVER A LA FUNCION SoapDocument.ValidElectronicCustomer

        if not EfAdministrationSetup.Get() then exit;
        if not EfAdministrationSetup."Use Electronic Service" then exit;
        CRLF[1] := 13;
        CRLF[2] := 10;

        MessageText := notificationHeaderLbl;
        CountyNotification.Scope := NotificationScope::LocalScope;
        if Rec."EF DR County Code" = '' then begin
            MessageText += CRLF + StrSubstNo(notificationCaptionLbl, 1) + StrSubstNo(notificationLbl, Rec.FieldCaption("EF DR County Code"), Rec.TableCaption());
            CountyNotification.Message(MessageText);
            CountyNotification.Send();
        end;

        if Rec."EF DR Township Code" = '' then begin
            MessageText := CRLF + StrSubstNo(notificationCaptionLbl, 2) + strSubstNo(notificationLbl, Rec.FieldCaption("EF DR Township Code"), Rec.TableCaption());
            TwonshipNotification.Message(MessageText);
            TwonshipNotification.Send();
        end;

        if Rec."E-Mail" = '' then begin
            MessageText := CRLF + StrSubstNo(notificationCaptionLbl, 4) + StrSubstNo(notificationLbl, Rec.FieldCaption("E-Mail"), Rec.TableCaption());
            EmailNotification.Message(MessageText);
            EmailNotification.Send();
        end;

    end;
}