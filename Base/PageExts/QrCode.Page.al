page 36003100 "LSEFQRCode"
{
    PageType = CardPart;
    DeleteAllowed = false;
    SourceTable = "LSC Transaction Header";

    layout
    {
        area(Content)
        {
            field("EF Encoded Barcode"; Rec.LSEfQRImage)
            {
                ApplicationArea = All;
                ShowCaption = false;
                Caption = 'Barcode Image';
                ToolTip = 'Shows Barcode Image';
            }
        }

    }
}