pageextension 36003100 "LSEF Transaction Register" extends "LSC Transaction Register"
{

    actions
    {
        // Add changes to page actions here
        addlast("T&ransaction")
        {
            separator(LSEFSeparator)
            {

            }
            action(LSEFDownloadXML)
            {
                Caption = 'Download EF XML';
                ToolTip = 'Download EF XML';
                ApplicationArea = All;
                Image = Download;
                trigger OnAction()
                var
                    SoapDocument: Codeunit "LSEF Soap Document";
                    EFSoapDocument: Codeunit "EF Soap Document";
                    XMLSourceToDownload: Text;
                    xmlDoc: XmlDocument;
                    InvalidTransLbl: Label 'Invalid Transaction %1, does not have a valid Electronic NCF', Comment = '%1 = Transaction Receipt No.';
                begin
                    if Rec."LSDX NCF" = '' then Error(InvalidTransLbl, Rec."Receipt No.");

                    if CopyStr(Rec."LSDX NCF", 1, 1) <> 'E' then Error(InvalidTransLbl, Rec."Receipt No.");
                    XMLSourceToDownload := SoapDocument.GetSalesPOSXML(Rec);
                    if XmlDocument.ReadFrom(XMLSourceToDownload, xmlDoc) then
                        EFSoapDocument.DownloadDocument(xmlDoc, Rec."LSDX NCF");
                end;
            }
            action(LSEFQR)
            {
                Caption = 'QR';
                ToolTip = 'QR';
                ApplicationArea = ALL;
                trigger OnAction()
                begin
                    Message(GenerateQRCode('https://ecf.dgii.gov.do/ecf/ConsultaTimbre?RncEmisor=102000621&RncComprador=101019921&ENCF=E310001173560&FechaEmision=14-09-2023&MontoTotal=118&FechaFirma=14-09-2023%207:04:09&CodigoSeguridad=f1Wh2Q'));
                end;

            }
        }
    }

    local procedure GenerateQRCode(BarcodeString: Text) QRCode: Text
    var
        BarcodeSymbology2D: Enum "Barcode Symbology 2D";
        BarcodeFontProvider2D: Interface "Barcode Font Provider 2D";

    begin
        BarcodeFontProvider2D := Enum::"Barcode Font Provider 2D"::IDAutomation2D;
        BarcodeSymbology2D := Enum::"Barcode Symbology 2D"::"QR-Code";
        QRCode := BarcodeFontProvider2D.EncodeFont(BarcodeString, BarcodeSymbology2D);
    end;
}