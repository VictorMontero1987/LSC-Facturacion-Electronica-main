codeunit 36003101 "LSEF LS Retail Events"
{
    trigger OnRun()
    begin

    end;

    var
        EfAdministrationSetup: Record "EF Administration Setup";
        CompanyInformation: Record "Company Information";
        DxNcfSetup: Record "DXNCF Setup";
        LSEFSoapDocument: Codeunit "LSEF Soap Document";
        EfSoapDocument: Codeunit "EF Soap Document";
        ValidationXML: XmlDocument;
        lXMLText: Text;



    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Post Utility", 'OnAfterPostTransaction', '', false, false)]
    local procedure OnAfterPostTransaction(var TransactionHeader_p: Record "LSC Transaction Header")
    begin
        LSEFSoapDocument.SendPOSDocument(TransactionHeader_p);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Post Utility", 'SalesEntryOnBeforeInsertV2', '', false, false)]
    local procedure SalesEntryOnBeforeInsert(Sign: Integer; var pPOSTransLineTemp: Record "LSC POS Trans. Line" temporary; var pTransSalesEntry: Record "LSC Trans. Sales Entry"; var Transaction: Record "LSC Transaction Header")
    var
        VatPostingSetup: Record "VAT Posting Setup";
        UnitOfMeasure: Record "Unit of Measure";
    begin
        VatPostingSetup.Reset();
        VatPostingSetup.SetCurrentKey("VAT Bus. Posting Group", "VAT Prod. Posting Group");
        VatPostingSetup.SetRange("VAT Bus. Posting Group", pTransSalesEntry."VAT Bus. Posting Group");
        VatPostingSetup.SetRange("VAT Prod. Posting Group", pTransSalesEntry."VAT Prod. Posting Group");
        if VatPostingSetup.FindFirst() then
            pTransSalesEntry."LSEF Tax Indicator" := VatPostingSetup."EF Tax Indicator";


        if UnitOfMeasure.Get(pTransSalesEntry."Unit of Measure") then
            pTransSalesEntry."LSEF UOM Type" := UnitOfMeasure."EF UOM Type";
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSDX POS Transaction", 'OnBeforeValidateFiscalData', '', false, false)]
    local procedure OnBeforeValidateFiscalDataForElectronicServices(var LscTransactionHeader: Record "LSC Transaction Header"; var IsHandled: Boolean)
    var
        ElectronicPosUtility: Codeunit "LSEF Electronic POS Utility";
    begin
        if not EfAdministrationSetup.Get() then exit;
        if not EfAdministrationSetup."LSEF Use Elec. Service On POS" then exit;
        IsHandled := ElectronicPosUtility.ValidateDataFiscal(LscTransactionHeader);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforePostPOSTransaction', '', false, false)]
    local procedure OnBeforePostPOSTransaction(var POSTransaction: Record "LSC POS Transaction")
    var
        dxNCFSalesSetup: Record "DXNCF Sales Setup";
        EfControlDigitsErr: Label '%1 must have a value 13 on table %2', Comment = '%1 = EF Controls Digits, %2 = DXNCF Setup Caption';
        NoFoundNCFErr: Label '%1 must have a value on table %2', Comment = '%1 = No. Series, %2 = DXNCF Sales Setup Caption';
    begin
        if not EfAdministrationSetup.Get() then exit;
        if not EfAdministrationSetup."LSEF Use Elec. Service On POS" then exit;
        if not DxNCFSetup.Get() then exit;

        if DxNcfSetup."Digitos e-CF" <> 13 then
            Error(EfControlDigitsErr, DxNcfSetup.FieldCaption("Digitos e-CF"), DxNcfSetup.TableCaption());

        dxNCFSalesSetup.Reset();
        dxNCFSalesSetup.SetFilter("No. Serie NCF Fact.", POSTransaction."LSDX No. Serie NCF");
        if not dxNCFSalesSetup.FindFirst() then
            Error(NoFoundNCFErr, POSTransaction."LSDX No. Serie NCF", dxNCFSalesSetup.TableCaption());

    end;

    [EventSubscriber(ObjectType::Page, Page::"Company Information", 'OnQueryClosePageEvent', '', false, false)]
    local procedure OnQueryCloseCompanyInformation(var Rec: Record "Company Information"; var AllowClose: Boolean)
    begin
        if not EfAdministrationSetup.Get() then exit;
        if not EfAdministrationSetup."LSEF Use Elec. Service On POS" then exit;

        Rec.TestField("EF DR Township Code");
        Rec.TestField("EF DR County Code");
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSDX POS Transaction", 'OnAfterInsertTransaction', '', true, false)]
    local procedure OnAfterInsertTransaction(var LscTransactionHeader: Record "LSC Transaction Header")
    var
        LscPosTerminal: Record "LSC POS Terminal";
        NoSeriesManagement: Codeunit NoSeriesManagement;
    begin
        if not EfAdministrationSetup.Get() then exit;
        if not EfAdministrationSetup."LSEF Use Elec. Service On POS" then exit;

        if LscPosTerminal.Get(LscTransactionHeader."POS Terminal No.") and LscTransactionHeader."LSEF Has Contingencies" then begin
            LscTransactionHeader.Validate("LSEF Alternal NCF", NoSeriesManagement.GetNextNo(LscPosTerminal."LSEF Alternal NCF SerialNo CRF", Today(), true));
            LscTransactionHeader."LSEF Alternal NCF Serial No." := LscPosTerminal."LSEF Alternal NCF SerialNo CRF";
            LscTransactionHeader.Modify(false);
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Print Utility", 'OnAfterPrintSalesSlip', '', TRUE, false)]
    local procedure OnAfterPrintSalesSlip(sender: Codeunit "LSC POS Print Utility"; var TransactionHeader: Record "LSC Transaction Header"; var POSPrintBuffer: Record "LSC POS Print Buffer"; var PrintBufferIndex: Integer; var LinesPrinted: Integer)
    var
        EfUtilityManagement: Codeunit "EF Utility Management";
        QRCodeText: Text;
        sgInstream: InStream;
        DSTR1: Text[100];
        FieldValue: array[10] of Text[100];
        SigValue: Text;
        ecfType: Code[2];
        hasContingencies: Boolean;
        SignedDate: Text[20];
        SecurityCodeLbl: Label 'Security Code: %1', Comment = '%1 Security Code from Transaction Header';
        SignedDateCaptionLbl: Label 'Stamped Date: %1', Comment = '%1 = Stamped Date of Electronic Transaction on the Transaction header';
    begin
        CompanyInformation.Get();
        if not EfAdministrationSetup.Get() then exit;
        if not EfAdministrationSetup."LSEF Use Elec. Service On POS" then exit;
        if not EfAdministrationSetup."LSEF Print QR Code" then exit;

        EfAdministrationSetup.TestField("LSEF Barcode Width");
        EfAdministrationSetup.TestField("LSEF Barcode Height");
        hasContingencies := TransactionHeader."LSEF Has Contingencies";

        if TransactionHeader."LSEF Signature Value".HasValue() then begin
            TransactionHeader."LSEF Signature Value".CreateInStream(sgInstream);
            sgInstream.Read(SigValue);
        end;

        if hasContingencies then begin
            ecfType := CopyStr(TransactionHeader."LSEF Alternal NCF", 2, 2);

            if (EfSoapDocument.GeteCFTypeFromString(ecfType) = "EF eCFType"::"E32 Final Consumer Invoice") then
                QRCodeText := EfUtilityManagement.GenerateQRURLConsumer(CopyStr(CompanyInformation."VAT Registration No.", 1, 15), CopyStr(TransactionHeader."LSEF Alternal NCF", 1, 13), Abs(TransactionHeader."Gross Amount"), TransactionHeader."LSEF Security Code")
            else
                QRCodeText := EfUtilityManagement.GenerateQRURL(CopyStr(CompanyInformation."VAT Registration No.", 1, 15), CopyStr(TransactionHeader."LSDX RNC/Cedula", 1, 15), CopyStr(TransactionHeader."LSDX NCF", 1, 13), TransactionHeader.Date, Abs(TransactionHeader."Gross Amount"), TransactionHeader."LSEF Stamped Date/Time", TransactionHeader."LSEF Security Code");

        end else begin

            ecfType := CopyStr(TransactionHeader."LSDX NCF", 2, 2);

            if (EfSoapDocument.GeteCFTypeFromString(ecfType) = "EF eCFType"::"E32 Final Consumer Invoice") then
                QRCodeText := EfUtilityManagement.GenerateQRURLConsumer(CopyStr(CompanyInformation."VAT Registration No.", 1, 15), CopyStr(TransactionHeader."LSDX NCF", 1, 13), Abs(TransactionHeader."Gross Amount"), TransactionHeader."LSEF Security Code")
            else
                QRCodeText := EfUtilityManagement.GenerateQRURL(CopyStr(CompanyInformation."VAT Registration No.", 1, 15), CopyStr(TransactionHeader."LSDX RNC/Cedula", 1, 15), CopyStr(TransactionHeader."LSDX NCF", 1, 13), TransactionHeader.Date, Abs(TransactionHeader."Gross Amount"), TransactionHeader."LSEF Stamped Date/Time", TransactionHeader."LSEF Security Code");
        end;

        if not hasContingencies then begin
            sender.PrintLine(2, '');

            sender.PrintBarcode(2, 'T' + TransactionHeader."Receipt No.", 8, 40, 'CODE128_A', 2);

            sender.PrintLine(2, '');

            sender.PrintBarcode(2, CopyStr(QRCodeText, 1, StrLen(QRCodeText)), EfAdministrationSetup."LSEF Barcode Width", EfAdministrationSetup."LSEF Barcode Height", 'QRCODE', 2);

            sender.PrintLine(2, '');

            DSTR1 := '#L######################################';
            FieldValue[1] := StrSubstNo(SecurityCodeLbl, TransactionHeader."LSEF Security Code");
            sender.PrintLine(2, sender.FormatLine(sender.FormatStr(FieldValue, DSTR1), false, true, false, false));

            DSTR1 := '#L######################################';
            SignedDate := TransactionHeader."LSEF Stamped Date/Time";
            FieldValue[1] := StrSubstNo(SignedDateCaptionLbl, Format(SignedDate, 0, '<Day, 2>-<Month, 2>-<Year4>'));
            sender.PrintLine(2, sender.FormatLine(sender.FormatStr(FieldValue, DSTR1), false, true, false, false));
        end
        else
            sender.PrintBarcode(2, 'T' + TransactionHeader."Receipt No.", 8, 40, 'CODE128_A', 2);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSDX LS Retail Events", 'OnBeforePrintNcfonPOS', '', false, false)]
    local procedure OnBeforePrintNcfonPOS(var sender: Codeunit "LSC Pos Print Utility"; var TransactionHeader: Record "LSC Transaction Header"; Tray: Integer; var POSPrintBuffer: Record "LSC POS Print Buffer"; var PrintBufferIndex: Integer; var LinesPrinted: Integer; var IsHandled: Boolean)
    var
        DSTR1: Text[100];
        FieldValue: array[10] of Text[80];
        NodeName: array[32] of Text[50];
    begin
        if not EfAdministrationSetup.Get() then exit;
        if not EfAdministrationSetup."LSEF Use Elec. Service On POS" then exit;

        if TransactionHeader."LSEF Has Contingencies" then begin
            Clear(FieldValue);
            DSTR1 := '#L## #L#################';
            FieldValue[1] := 'NCF: ';
            NodeName[1] := 'x';
            FieldValue[2] := TransactionHeader."LSEF Alternal NCF";
            sender.PrintLine(Tray, sender.FormatLine(sender.FormatStr(FieldValue, DSTR1), false, true, false, false));
            sender.AddPrintLine(200, 3, NodeName, FieldValue, DSTR1, false, true, false, false, Tray);

            if TransactionHeader."Sale Is Return Sale" then begin
                Clear(FieldValue);
                DSTR1 := '#L########### #L#################';
                FieldValue[1] := 'NCF Affectado: ';
                NodeName[1] := 'x';
                FieldValue[2] := TransactionHeader."LSDX NCF Afectado";
                sender.PrintLine(Tray, sender.FormatLine(sender.FormatStr(FieldValue, DSTR1), false, true, false, false));
                sender.AddPrintLine(200, 3, NodeName, FieldValue, DSTR1, false, true, false, false, Tray);
            end;
            IsHandled := true;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"EF Event Pusblishers", 'OnBeforeProcessResendRequest', '', false, false)]
    local procedure OnBeforeProcessResendRequest(var pProcessRequest: Record "EF Process Request"; var Resend: Boolean; var IsHandled: Boolean)
    var
        TransactionHeader_p: record "LSC Transaction Header";
        IsSuccess: Boolean;
    begin


        if not EfAdministrationSetup.Get() then exit;
        if not EfAdministrationSetup."LSEF Use Elec. Service On POS" then exit;
        if not DxNcfSetup.Get() then exit;
        if pProcessRequest."EF Source Code Type" <> pProcessRequest."EF Source Code Type"::POS then exit;

        TransactionHeader_p.SetCurrentKey("Store No.", "POS Terminal No.", "Receipt No.");
        TransactionHeader_p.SetRange("Store No.", pProcessRequest."LSEF Store No.");
        TransactionHeader_p.SetRange("POS Terminal No.", pProcessRequest."LSEF POS Terminal No.");
        TransactionHeader_p.SetRange("Receipt No.", pProcessRequest."Document No.");

        if not TransactionHeader_p.FindLast() then exit;

        IsSuccess := LSEFSoapDocument.SendPOSDocument(TransactionHeader_p);

        Resend := IsSuccess;
        IsHandled := true;
    end;
}