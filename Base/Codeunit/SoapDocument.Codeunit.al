codeunit 36003100 "LSEF Soap Document"
{
    trigger OnRun()
    begin

    end;

    var
        EfAdministrationSetup: Record "EF Administration Setup";
        EfUtilityManagement: Codeunit "EF Utility Management";
        EfSoapDocument: Codeunit "EF Soap Document";
        LSEFElectronicPOSUtility: codeunit "LSEF Electronic POS Utility";

    #Region Ventas POS    
    procedure GetSalesPOSXML(var LSCTransactionHeader: record "LSC Transaction Header") ResultXML: Text
    var
        EFEncabezado: record "EF Encabezado";
    begin
        clear(EFEncabezado);
        EFEncabezado.SetRange(DocumentNo, LSCTransactionHeader."Receipt No.");
        if EFEncabezado.FindFirst() then
            if EFEncabezado.Delete(true) then;

        if FillFromPOSTables(LSCTransactionHeader, EFEncabezado) then
            ResultXML := EfSoapDocument.CreateXML(EFEncabezado);

        if EFEncabezado.Delete(true) then;

        exit(ResultXML);
    end;

    local procedure FillFromPOSTables(var LSCTransactionHeader: Record "LSC Transaction Header"; var EFEncabezado: record "EF Encabezado") Result: Boolean
    begin
        clear(EFEncabezado);

        if LSCTransactionHeader."Transaction Type" <> LSCTransactionHeader."Transaction Type"::Sales then
            exit(false);

        Result := FillFromSalesPOSTables(LSCTransactionHeader, EFEncabezado);

        exit(Result);
    end;

    local procedure FillFromSalesPOSTables(var LSCTransactionHeader: Record "LSC Transaction Header"; var EFEncabezado: record "EF Encabezado"): Boolean
    var
        CompanyInformation: Record "Company Information";
        Currency: Record Currency;
        CustomerBuyer: Record Customer;

        Item: Record Item;
        PaymentTerms: Record "Payment Terms";

        ServiceZone: Record "Service Zone";
        CurrencyFactor: Decimal;
        Itbis1: Decimal;
        Itbis2: Decimal;
        Itbis3: Decimal;
        MontoExento: Decimal;
        MontoGrabado1: Decimal;
        MontoGrabado2: Decimal;
        MontoGrabado3: Decimal;
        MontoGrabadoTotal: Decimal;
        MontoTotal: Decimal;
        NoInvoiceAmount: Decimal;
        PeriodAmount: Decimal;
        TotalItbis1: Decimal;
        TotalItbis2: Decimal;
        TotalItbis3: Decimal;
        ValuePayable: Decimal;
        VatAmountTotalAnotherCurrency: Decimal;
        ItemLines: Integer;
        IndicadorBienoServicioValue: Text[1];
        EFFormasdePago: record "EF Formas de Pago";
        EFTelefonoEmisor: record "EF Telefono Emisor";
        DxDgiiRncDatabaseEmisor: record "DXDGII-RNC Database";
        DxDgiiRncDatabaseComprador: record "DXDGII-RNC Database";
        EFImpAdicionalesEncab: record "EF Imp. Adicionales - Encab.";

        EFDetalleBienesoServicios: record "EF Detalle Bienes o Servicios";
        EFCodigosItem: record "EF Codigos Item";
        EFSubcantidad: record "EF Subcantidad";
        EFSubDescuento: record "EF SubDescuento";
        EFImpuestosAdicionalesDBS: record "EF Impuestos Adicionales - DBS";
        EFSubTotalesInformativos: record "EF SubTotales Informativos";
        EFPaginacion: record "EF Paginacion";
        EFInformacionReferencia: RECORD "EF Informacion Referencia";
        //---
        AffectedTransactionHeader: Record "LSC Transaction Header";
        LscTransSalesEntry: Record "LSC Trans. Sales Entry";
        LscTransPaymentEntry: Record "LSC Trans. Payment Entry";
        LsdxTenderTypesRelation: Record "LSDXTender Types Relation";
        VatPostingSetup: Record "VAT Posting Setup";
        NoNcfErr: Label 'Receipt %1 does not have eNCF on Transaction %2 For Terminal %3', Comment = '%1 = Receipt No., %2 = Transacton No., %3 = Termninal No.';

        ecfType: Code[2];
    begin

        if LscTransactionHeader."LSDX NCF" = '' then
            Error(NoNcfErr, LscTransactionHeader."Receipt No.", LscTransactionHeader."Transaction No.", LscTransactionHeader."POS Terminal No.");

        CompanyInformation.Get();
        if CompanyInformation."VAT Registration No." <> '' then begin
            DxDgiiRncDatabaseEmisor.Reset();
            DxDgiiRncDatabaseEmisor.SetCurrentKey(RNC);
            DxDgiiRncDatabaseEmisor.Get(CompanyInformation."VAT Registration No.");
        end;
        CompanyInformation.CalcFields("EF DR County Code", "EF DR Township Code");
        if LscTransactionHeader."Customer No." <> '' then begin
            Clear(CustomerBuyer);
            if CustomerBuyer.Get(LscTransactionHeader."Customer No.") then;
            if ServiceZone.Get(CustomerBuyer."Service Zone Code") then;
            if DxDgiiRncDatabaseComprador.Get(CustomerBuyer."VAT Registration No.") then;
            PaymentTerms.Get(CustomerBuyer."Payment Terms Code");
            CustomerBuyer.CalcFields("EF DR County Code", "EF DR Township Code");
        end;

        CurrencyFactor := 1;
        EFEncabezado.DocumentNo := LSCTransactionHeader."Receipt No.";
        EFEncabezado.Version := '1.0';
        ecfType := CopyStr(LscTransactionHeader."LSDX NCF", 2, 2);
        Evaluate(EFEncabezado.TipoeCF, ecfType);

        EFEncabezado.eNCF := CopyStr(LSCTransactionHeader."LSDX NCF", 1, MaxStrLen(EFEncabezado.eNCF));
        EFEncabezado.FechaVencimientoSecuencia := LscTransactionHeader."LSDX Fecha Expiracion NCF";

        if LscTransactionHeader."Sale Is Return Sale" then begin
            AffectedTransactionHeader.Reset();
            AffectedTransactionHeader.SetRange("Receipt No.", LscTransactionHeader."Retrieved from Receipt No.");
            if AffectedTransactionHeader.FindFirst() then
                EFEncabezado.IndicadorNotaCredito := (LscTransactionHeader.Date - AffectedTransactionHeader.Date) > 30;

        end;

        EFEncabezado.IndicadorEnvioDiferido := true;
        EFEncabezado.IndicadorMontoGravado := false;
        EFEncabezado.TipoIngresos := 1; //TODO: De donde se debe tomar este valor?

        //TODO: Para este valor deberiamos buscar la linea con monto mayor.
        Clear(LscTransPaymentEntry);
        LscTransPaymentEntry.SETRANGE("Store No.", LscTransactionHeader."Store No.");
        LscTransPaymentEntry.SETRANGE("POS Terminal No.", LscTransactionHeader."POS Terminal No.");
        LscTransPaymentEntry.SETRANGE("Transaction No.", LscTransactionHeader."Transaction No.");
        Clear(LsdxTenderTypesRelation);
        if LscTransPaymentEntry.FindFirst() then begin
            CLEAR(LsdxTenderTypesRelation);
            LsdxTenderTypesRelation.SetRange("Tender Type Code", LscTransPaymentEntry."Tender Type");
            if LsdxTenderTypesRelation.FindFirst() then
                EFEncabezado.TipoPago := LsdxTenderTypesRelation."LSEF Payment Type".AsInteger();
        end;

        EFEncabezado.FechaLimitePago := LSCTransactionHeader.Date;
        EFEncabezado.TerminoPago := copystr(PaymentTerms.Description, 1, MaxStrLen(EFEncabezado.TerminoPago));

        Clear(LscTransPaymentEntry);
        LscTransPaymentEntry.SETRANGE("Store No.", LscTransactionHeader."Store No.");
        LscTransPaymentEntry.SETRANGE("POS Terminal No.", LscTransactionHeader."POS Terminal No.");
        LscTransPaymentEntry.SETRANGE("Transaction No.", LscTransactionHeader."Transaction No.");
        if LscTransPaymentEntry.FindSet() then
            repeat
                clear(LsdxTenderTypesRelation);
                LsdxTenderTypesRelation.SetRange("Tender Type Code", LscTransPaymentEntry."Tender Type");
                if LsdxTenderTypesRelation.FindFirst() then begin
                    Clear(EFFormasdePago);
                    EFFormasdePago.DocumentNo := EFEncabezado.DocumentNo;
                    EFFormasdePago.FormaPago := LsdxTenderTypesRelation."LSEF Payment Type Form";
                    EFFormasdePago.MontoPago := Abs(LscTransPaymentEntry."Amount Tendered") / CurrencyFactor;
                    EFFormasdePago.Insert(true);
                end;
            until LscTransPaymentEntry.Next() = 0;


        //Area Emisor
        EFEncabezado.RNCEmisor := CopyStr(CompanyInformation."VAT Registration No.", 1, MaxStrLen(EFEncabezado.RNCEmisor));
        EFEncabezado.RazonSocialEmisor := CopyStr(DxDgiiRncDatabaseEmisor."Nombre/Razon Social", 1, MaxStrLen(EFEncabezado.RazonSocialEmisor));
        EFEncabezado.NombreComercial := CompanyInformation.Name;
        EFEncabezado.DireccionEmisor := CompanyInformation.Address;
        EFEncabezado.Municipio := CopyStr(CompanyInformation."EF DR Township Code", 1, MaxStrLen(EFEncabezado.Municipio));
        EFEncabezado.Provincia := CopyStr(CompanyInformation."EF DR County Code", 1, MaxStrLen(EFEncabezado.Provincia));

        // Tabla Telefono Emisor
        clear(EFTelefonoEmisor);
        EFTelefonoEmisor.DocumentNo := EFEncabezado.DocumentNo;
        EFTelefonoEmisor.TelefonoEmisor := CompanyInformation."Phone No.";
        EFTelefonoEmisor.Insert(true);

        clear(EFTelefonoEmisor);
        EFTelefonoEmisor.DocumentNo := EFEncabezado.DocumentNo;
        EFTelefonoEmisor.TelefonoEmisor := CompanyInformation."Phone No. 2";
        EFTelefonoEmisor.Insert(true);

        EFEncabezado.CorreoEmisor := CompanyInformation."E-Mail";
        EFEncabezado.WebSite := CopyStr(CompanyInformation."Home Page", 1, MaxStrLen(EFEncabezado.WebSite));
        EFEncabezado.ActividadEconomica := DxDgiiRncDatabaseEmisor."Area Negocio";
        EFEncabezado.CodigoVendedor := LscTransactionHeader."Staff ID";
        //TODO: Este campo no se puede enviar, ya que tiene letras y el XML solo permite numeros.
        EFEncabezado.NumeroFacturaInterna := LscTransactionHeader."Receipt No.";
        EFEncabezado.NumeroPedidoInterno := LscTransactionHeader."Receipt No.";
        EFEncabezado.FechaEmision := LscTransactionHeader.Date;
        EFEncabezado.ZonaVenta := ServiceZone.Code;
        EFEncabezado.RutaVenta := '';

        // Area Comprador
        EFEncabezado.RNCComprador := CopyStr(CustomerBuyer."VAT Registration No.", 1, MaxStrLen(EFEncabezado.RNCComprador));
        //TODO: VALIDAR DE DONDE SE VA A TOMAR ESTE VALOR IdentificadorExtranjero
        // Corresponde al número de identificación cuando el comprador es extranjero y no tiene RNC/Cédula.
        EFEncabezado.IdentificadorExtranjero := '';
        EFEncabezado.RazonSocialComprador := DxDgiiRncDatabaseComprador."Nombre/Razon Social";
        EFEncabezado.ContactoComprador := CustomerBuyer."Phone No.";
        EFEncabezado.CorreoComprador := CustomerBuyer."E-Mail";
        EFEncabezado.DireccionComprador := CustomerBuyer.Address;
        EFEncabezado.MunicipioComprador := CustomerBuyer."EF DR Township Code";
        EFEncabezado.ProvinciaComprador := CustomerBuyer."EF DR County Code";
        EFEncabezado.PaisComprador := CustomerBuyer.City;

        // Area Informaciones Adicionales

        // Area Transporte

        //Area Totales
        MontoGrabadoTotal := 0;
        MontoGrabado1 := 0;
        MontoGrabado2 := 0;
        MontoGrabado3 := 0;
        Itbis1 := 0;
        Itbis2 := 0;
        Itbis3 := 0;
        Clear(LscTransSalesEntry);
        LscTransSalesEntry.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.");
        LscTransSalesEntry.SetRange("Store No.", LscTransactionHeader."Store No.");
        LscTransSalesEntry.SetRange("POS Terminal No.", LscTransactionHeader."POS Terminal No.");
        LscTransSalesEntry.SetRange("Transaction No.", LscTransactionHeader."Transaction No.");
        LscTransSalesEntry.SetFilter("LSEF Tax Indicator", '<>%1', LscTransSalesEntry."LSEF Tax Indicator"::"Exento (E)");
        if LscTransSalesEntry.FindSet() then begin
            LscTransSalesEntry.CalcSums("Net Amount");
            MontoGrabadoTotal := Abs(LscTransSalesEntry."Net Amount");
        end;

        EFEncabezado.MontoGravadoTotal := Abs(MontoGrabadoTotal) / CurrencyFactor;

        clear(LscTransSalesEntry);
        LscTransSalesEntry.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.");
        LscTransSalesEntry.SetRange("Store No.", LscTransactionHeader."Store No.");
        LscTransSalesEntry.SetRange("POS Terminal No.", LscTransactionHeader."POS Terminal No.");
        LscTransSalesEntry.SetRange("Transaction No.", LscTransactionHeader."Transaction No.");
        if LscTransSalesEntry.FindSet() then
            repeat
                if VatPostingSetup.Get(LscTransSalesEntry."VAT Bus. Posting Group", LscTransSalesEntry."VAT Prod. Posting Group") then;

                case LscTransSalesEntry."LSEF Tax Indicator" of
                    LscTransSalesEntry."LSEF Tax Indicator"::"ITBIS 1 (18%)":
                        begin
                            MontoGrabado1 += Abs(LscTransSalesEntry."Net Amount");
                            Itbis1 := Abs(VatPostingSetup."VAT %");
                            TotalItbis1 += Abs(LscTransSalesEntry."VAT Amount");
                        end;
                    LscTransSalesEntry."LSEF Tax Indicator"::"ITBIS 2 (16%)":
                        begin
                            MontoGrabado2 += Abs(LscTransSalesEntry."Net Amount");
                            Itbis2 := Abs(VatPostingSetup."VAT %");
                            TotalItbis2 += Abs(LscTransSalesEntry."VAT Amount");
                        end;
                    LscTransSalesEntry."LSEF Tax Indicator"::"ITBIS 3 (0%)":
                        begin
                            MontoGrabado3 += Abs(LscTransSalesEntry."Net Amount");
                            Itbis3 := Abs(VatPostingSetup."VAT %");
                            TotalItbis3 += Abs(LscTransSalesEntry."VAT Amount");
                        end;
                    LscTransSalesEntry."LSEF Tax Indicator"::"Exento (E)":
                        MontoExento += Abs(LscTransSalesEntry."Net Amount");
                end;
            until LscTransSalesEntry.Next() = 0;

        EFEncabezado.MontoGravadoI1 := Abs(MontoGrabado1) / CurrencyFactor;
        EFEncabezado.MontoGravadoI2 := Abs(MontoGrabado2) / CurrencyFactor;
        EFEncabezado.MontoGravadoI3 := Abs(MontoGrabado3) / CurrencyFactor;
        EFEncabezado.MontoExento := Abs(MontoExento) / CurrencyFactor;

        EFEncabezado.ITBIS1 := Abs(Itbis1);
        EFEncabezado.ITBIS2 := Abs(Itbis2);
        EFEncabezado.ITBIS3 := Abs(Itbis3);
        EFEncabezado.TotalITBIS := Abs((TotalItbis1) + TotalItbis2 + TotalItbis3) / CurrencyFactor;
        EFEncabezado.TotalITBIS1 := Abs(TotalItbis1) / CurrencyFactor;
        EFEncabezado.TotalITBIS2 := Abs(TotalItbis2) / CurrencyFactor;
        EFEncabezado.TotalITBIS3 := Abs(TotalItbis3) / CurrencyFactor;
        EFEncabezado.MontoImpuestoAdicional := Abs(0);

        if LscTransactionHeader."LSEF Applies for ISC" then begin
            Clear(LscTransSalesEntry);
            LscTransSalesEntry.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.");
            LscTransSalesEntry.SetRange("Store No.", LscTransactionHeader."Store No.");
            LscTransSalesEntry.SetRange("POS Terminal No.", LscTransactionHeader."POS Terminal No.");
            LscTransSalesEntry.SetRange("Transaction No.", LscTransactionHeader."Transaction No.");
            LscTransSalesEntry.SetRange("LSEF Applies for ISC", true);
            if LscTransSalesEntry.Find('-') then
                repeat
                    Clear(Item);
                    if Item.Get(LscTransSalesEntry."Item No.") then begin
                        clear(EFImpAdicionalesEncab);
                        EFImpAdicionalesEncab.DocumentNo := EFEncabezado.DocumentNo;
                        EFImpAdicionalesEncab.TipoImpuesto := Item."EF Tax Type";
                        EFImpAdicionalesEncab.TasaImpuestoAdicional := Abs(0) / CurrencyFactor;
                        EFImpAdicionalesEncab.MontoImpSelecConsumoEspecifico := Abs(0) / CurrencyFactor;
                        EFImpAdicionalesEncab.MontoImpSelConsumoAdvalorem := Abs(0) / CurrencyFactor;
                        EFImpAdicionalesEncab.OtrosImpuestosAdicionales := Abs(0) / CurrencyFactor;

                        // En Divisa
                        EFImpAdicionalesEncab.TipoImpuestoOtraMoneda := Item."EF Tax Type";
                        EFImpAdicionalesEncab.TasaImpuestoAdicionalOMoneda := Abs(0);
                        EFImpAdicionalesEncab.MontoImpSelecConsumoEspOMoneda := Abs(0);
                        EFImpAdicionalesEncab.MontoImpSelConsumoAdOtraMoneda := Abs(0);
                        EFImpAdicionalesEncab.OtrosImpuestosAdicionalOMoneda := Abs(0);
                        EFImpAdicionalesEncab.Insert(true);
                    end;
                until LscTransSalesEntry.Next() = 0;
        end;

        MontoTotal := Abs((MontoGrabadoTotal + MontoExento + (TotalItbis1 + TotalItbis2 + TotalItbis3)));
        EFEncabezado.MontoTotal := Abs(MontoTotal) / CurrencyFactor;

        Clear(LscTransSalesEntry);
        LscTransSalesEntry.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.");
        LscTransSalesEntry.SetRange("Store No.", LscTransactionHeader."Store No.");
        LscTransSalesEntry.SetRange("POS Terminal No.", LscTransactionHeader."POS Terminal No.");
        LscTransSalesEntry.SetRange("Transaction No.", LscTransactionHeader."Transaction No.");
        LscTransSalesEntry.SetRange("Net Amount", 0);
        if LscTransSalesEntry.Find('-') then
            repeat
                Clear(Item);
                if Item.Get(LscTransSalesEntry."Item No.") then
                    NoInvoiceAmount += Abs(Item."Unit Price") * Abs(LscTransSalesEntry.Quantity);
            until LscTransSalesEntry.Next() = 0;

        EFEncabezado.MontoNoFacturable := Abs(NoInvoiceAmount) / CurrencyFactor;
        PeriodAmount := Abs(MontoTotal + NoInvoiceAmount);
        EFEncabezado.MontoPeriodo := Abs(PeriodAmount) / CurrencyFactor;
        EFEncabezado.SaldoAnterior := Abs(0);
        EFEncabezado.MontoAvancePago := Abs(0);
        ValuePayable := Abs(MontoTotal + EFEncabezado.MontoAvancePago);
        EFEncabezado.ValorPagar := Abs(ValuePayable) / CurrencyFactor;

        //Otra Moneda Area
        if LscTransactionHeader."Trans. Currency" <> '' then begin

            if Currency.Get(LscTransactionHeader."Trans. Currency") then;

            EFEncabezado.TipoMoneda := Currency."EF Currency Type";
            EFEncabezado.TipoCambio := 1 / CurrencyFactor;
            EFEncabezado.MontoGravadoTotalOtraMoneda := Abs(MontoGrabadoTotal);
            EFEncabezado.MontoGravado1OtraMoneda := Abs(MontoGrabado1);
            EFEncabezado.MontoGravado2OtraMoneda := Abs(MontoGrabado2);
            EFEncabezado.MontoGravado3OtraMoneda := Abs(MontoGrabado3);
            EFEncabezado.MontoExentoOtraMoneda := Abs(MontoExento);

            VatAmountTotalAnotherCurrency := Abs(TotalItbis1 + TotalItbis2 + TotalItbis3);
            EFEncabezado.TotalITBISOtraMoneda := Abs(VatAmountTotalAnotherCurrency);
            EFEncabezado.TotalITBIS1OtraMoneda := Abs(TotalItbis1);
            EFEncabezado.TotalITBIS2OtraMoneda := Abs(TotalItbis2);
            EFEncabezado.TotalITBIS3OtraMoneda := Abs(TotalItbis3);
            EFEncabezado.MontoTotalOtraMoneda := Abs(MontoTotal);
        end;


        Clear(LscTransSalesEntry);
        LscTransSalesEntry.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.");
        LscTransSalesEntry.SetRange("Store No.", LscTransactionHeader."Store No.");
        LscTransSalesEntry.SetRange("POS Terminal No.", LscTransactionHeader."POS Terminal No.");
        LscTransSalesEntry.SetRange("Transaction No.", LscTransactionHeader."Transaction No.");
        ItemLines := 0;
        if LscTransSalesEntry.Find('-') then
            repeat
                Clear(Item);
                if Item.Get(LscTransSalesEntry."Item No.") then;
                clear(EFDetalleBienesoServicios);
                ItemLines += 1;
                EFDetalleBienesoServicios.DocumentNo := EFEncabezado.DocumentNo;
                EFDetalleBienesoServicios.DocumentLineNo := LscTransSalesEntry."Line No.";
                EFDetalleBienesoServicios.NumeroLinea := ItemLines;

                // CODIGOS ITEMS
                clear(EFCodigosItem);
                EFCodigosItem.DocumentNo := EFEncabezado.DocumentNo;
                EFCodigosItem.DocumentLineNo := EFDetalleBienesoServicios.DocumentLineNo;
                EFCodigosItem.CodigoItem := LscTransSalesEntry."Item No.";
                EFCodigosItem.TipoCodigo := 'Interna';
                EFCodigosItem.Insert(true);

                EFDetalleBienesoServicios.IndicadorFacturacion := LscTransSalesEntry."LSEF Tax Indicator".AsInteger();
                EFDetalleBienesoServicios.NombreItem := CopyStr(Item.Description, 1, MaxStrLen(EFDetalleBienesoServicios.NombreItem));
                if Item.Type = "Item Type"::Inventory then
                    IndicadorBienoServicioValue := Format(1)
                else
                    IndicadorBienoServicioValue := Format(2);
                EFDetalleBienesoServicios.IndicadorBienoServicio := IndicadorBienoServicioValue;
                EFDetalleBienesoServicios.DescripcionItem := Item."Description 2";
                EFDetalleBienesoServicios.CantidadItem := Abs(LscTransSalesEntry.Quantity);
                EFDetalleBienesoServicios.UnidadMedida := LscTransSalesEntry."LSEF UOM Type";

                if LscTransSalesEntry."LSEF Applies for ISC" then begin
                    EFDetalleBienesoServicios.CantidadReferencia := 0;
                    EFDetalleBienesoServicios.UnidadReferencia := '';

                    // TablaSubcantidad
                    // ESTA AREA NO ESTA IMPLEMENTADA
                    clear(EFSubcantidad);
                    EFSubcantidad.Init();
                    EFSubcantidad.DocumentNo := EFEncabezado.DocumentNo;
                    EFSubcantidad.DocumentLineNo := EFDetalleBienesoServicios.DocumentLineNo;
                    EFSubcantidad.Insert(true);

                    EFDetalleBienesoServicios.GradosAlcohol := 0;
                    EFDetalleBienesoServicios.PrecioUnitarioReferencia := 0;

                end;

                EFDetalleBienesoServicios.PrecioUnitarioItem := Abs(LscTransSalesEntry."Net Price") / CurrencyFactor;

                if (Abs(LscTransSalesEntry."Discount Amount") > 0) then begin


                    EFDetalleBienesoServicios.DescuentoMonto := Abs(LscTransSalesEntry."Discount Amount") / CurrencyFactor;

                    clear(EFSubDescuento);
                    EFSubDescuento.DocumentNo := EFDetalleBienesoServicios.DocumentNo;
                    EFSubDescuento.DocumentLineNo := EFDetalleBienesoServicios.DocumentLineNo;
                    EFSubDescuento.TipoSubDescuento := '$';
                    EFSubDescuento.SubDescuentoPorcentaje := 0;
                    EFSubDescuento.MontoSubDescuento := Abs(LscTransSalesEntry."Discount Amount") / CurrencyFactor;
                    EFSubDescuento.Insert(true);
                end;

                // Tabla SubRecargo
                // clear(EFSubRecargo);
                // EFSubRecargo.Init();
                // EFSubRecargo.DocumentNo := EFEncabezado.DocumentNo;
                // EFSubRecargo.Insert(true);

                // Tabla Impuesto Adicional
                if LscTransSalesEntry."LSEF Applies for ISC" then begin
                    clear(EFImpuestosAdicionalesDBS);
                    EFImpuestosAdicionalesDBS.DocumentNo := EFDetalleBienesoServicios.DocumentNo;
                    EFImpuestosAdicionalesDBS.DocumentLineNo := EFDetalleBienesoServicios.DocumentLineNo;
                    EFImpuestosAdicionalesDBS.Init();
                    EFImpuestosAdicionalesDBS.Insert(true);
                end;

                if LSCTransactionHeader."Trans. Currency" <> '' then begin
                    EFDetalleBienesoServicios.PrecioOtraMoneda := Abs(LscTransSalesEntry.Price);
                    EFDetalleBienesoServicios.DescuentoOtraMoneda := Abs(LscTransSalesEntry."Discount Amount");
                    EFDetalleBienesoServicios.RecargoOtraMoneda := Abs(0);
                    EFDetalleBienesoServicios.MontoItemOtraMoneda := Abs(LscTransSalesEntry."Net Amount");
                end;

                EFDetalleBienesoServicios.MontoItem := Abs(LscTransSalesEntry."Net Amount") / CurrencyFactor;
                EFDetalleBienesoServicios.Insert(true);
            until LscTransSalesEntry.Next() = 0;

        clear(EFSubTotalesInformativos);
        EFSubTotalesInformativos.DocumentNo := EFEncabezado.DocumentNo;
        EFSubTotalesInformativos.NumeroSubTotal := 1;
        EFSubTotalesInformativos.DescripcionSubtotal := 'Montos Factura';
        EFSubTotalesInformativos.Orden := 1;

        EFSubTotalesInformativos.SubTotalMontoGravadoTotal := Abs((MontoGrabado1 + MontoGrabado2 + MontoGrabado3)) / CurrencyFactor;
        EFSubTotalesInformativos.SubTotalMontoGravadoI1 := Abs(MontoGrabado1) / CurrencyFactor;
        EFSubTotalesInformativos.SubTotalMontoGravadoI2 := Abs(MontoGrabado2) / CurrencyFactor;
        EFSubTotalesInformativos.SubTotalMontoGravadoI3 := Abs(MontoGrabado3) / CurrencyFactor;
        EFSubTotalesInformativos.SubTotaITBIS := Abs((TotalItbis1 + TotalItbis2 + TotalItbis3)) / CurrencyFactor;
        EFSubTotalesInformativos.SubTotaITBIS1 := Abs(TotalItbis1) / CurrencyFactor;
        EFSubTotalesInformativos.SubTotaITBIS2 := Abs(TotalItbis2) / CurrencyFactor;
        EFSubTotalesInformativos.SubTotaITBIS3 := Abs(TotalItbis3) / CurrencyFactor;

        EFSubTotalesInformativos.SubTotalImpuestoAdicional := 0;

        EFSubTotalesInformativos.SubTotalExento := Abs(MontoExento) / CurrencyFactor;
        EFSubTotalesInformativos.MontoSubTotal := Abs(((MontoGrabado1 + MontoGrabado2 + MontoGrabado3) + (TotalItbis1 + TotalItbis2 + TotalItbis3) + MontoExento)) / CurrencyFactor;
        EFSubTotalesInformativos.Lineas := 1;
        EFSubTotalesInformativos.Insert(true);

        //Area Descuento Recargos
        // clear(EFDescuentosORecargos);
        // EFDescuentosORecargos.Init();
        // EFDescuentosORecargos.DocumentNo := EFEncabezado.DocumentNo;
        // EFDescuentosORecargos.Insert(true);

        // Area Paginacion
        clear(EFPaginacion);
        EFPaginacion.DocumentNo := EFEncabezado.DocumentNo;
        EFPaginacion.Init();
        EFPaginacion.Insert(true);

        //Area Informacion Referencia
        if LSCTransactionHeader."Sale Is Return Sale" then begin
            Clear(EFInformacionReferencia);
            EFInformacionReferencia.DocumentNo := EFEncabezado.DocumentNo;
            EFInformacionReferencia.NCFModificado := CopyStr(LscTransactionHeader."LSDX NCF Afectado", 1, MaxStrLen(EFInformacionReferencia.NCFModificado));
            EFInformacionReferencia.RNCOtroContribuyente := '';
            EFInformacionReferencia.CodigoModificacion := LscTransactionHeader."LSEF NCF Modification Reason";
            EFInformacionReferencia.RazonModificacion := '';

            AffectedTransactionHeader.Reset();
            AffectedTransactionHeader.SetRange("LSDX NCF", LscTransactionHeader."LSDX NCF Afectado");
            if AffectedTransactionHeader.FindFirst() then
                EFInformacionReferencia.FechaNCFModificado := AffectedTransactionHeader.Date;

            EFInformacionReferencia.Insert(true);
        end else
            if LSCTransactionHeader."LSEF Has Contingencies" then begin
                Clear(EFInformacionReferencia);
                EFInformacionReferencia.DocumentNo := EFEncabezado.DocumentNo;
                EFInformacionReferencia.NCFModificado := CopyStr(LscTransactionHeader."LSEF Alternal NCF", 1, MaxStrLen(EFInformacionReferencia.NCFModificado));
                EFInformacionReferencia.RNCOtroContribuyente := '';
                EFInformacionReferencia.CodigoModificacion := 4; //TODO: Asignar este campo por configuracion.
                EFInformacionReferencia.RazonModificacion := '';
                EFInformacionReferencia.FechaNCFModificado := LscTransactionHeader.Date;

                EFInformacionReferencia.Insert(true);

            end;

        EFEncabezado.Insert(true);

        exit(true);

    end;

    procedure GetEF32ResumeXML(var LSCTransactionHeader: Record "LSC Transaction Header") ResultXML: Text
    var
        EFEncabezado: record "EF Encabezado";
    begin

        clear(EFEncabezado);
        EFEncabezado.SetRange(DocumentNo, LSCTransactionHeader."Receipt No.");
        if EFEncabezado.FindFirst() then
            if EFEncabezado.Delete(true) then;

        if FillFromPOSTables(LSCTransactionHeader, EFEncabezado) then
            ResultXML := EfSoapDocument.CreateEF32ResumeXML(EFEncabezado);

        if EFEncabezado.Delete(true) then;

        exit(ResultXML);
    end;

    procedure SendPOSDocument(var TransactionHeader_p: record "LSC Transaction Header"): Boolean
    var
        EfProcessRequest: Record "EF Process Request";
        LSCPOSTerminal: Record "LSC POS Terminal";
        CompanyInformation: Record "Company Information";
        DxNcfSetup: Record "DXNCF Setup";
        NoSeriesManagement: Codeunit NoSeriesManagement;
        LSEFSoapDocument: Codeunit "LSEF Soap Document";
        QRCodeText: Text;
        IsSuccess: Boolean;
        lXMLText: Text;
    begin
        if not EfAdministrationSetup.Get() then exit;
        if not EfAdministrationSetup."LSEF Use Elec. Service On POS" then exit;
        if not DxNcfSetup.Get() then exit;

        CompanyInformation.Get();

        if TransactionHeader_p."Entry Status" in [TransactionHeader_p."Entry Status"::Voided] then exit;
        if TransactionHeader_p."Transaction Type" <> TransactionHeader_p."Transaction Type"::Sales then exit;
        if TransactionHeader_p."LSDX NCF" = '' then exit;

        lXMLText := LSEFSoapDocument.GetSalesPOSXML(TransactionHeader_p);
        IsSuccess := LSEFSoapDocument.SendXmlElectronicDocument(lXMLText, TransactionHeader_p."LSDX NCF", false, TransactionHeader_p."Receipt No.");

        if IsSuccess and (TransactionHeader_p."LSEF e-NCF Type" = TransactionHeader_p."LSEF e-NCF Type"::"E32 Final Consumer Invoice") and (TransactionHeader_p."Net Amount" < DxNcfSetup."Max Amount without RNC/Cedula") then begin
            lXMLText := LSEFSoapDocument.GetEF32ResumeXML(TransactionHeader_p);
            IsSuccess := LSEFSoapDocument.SendXmlElectronicDocument(lXMLText, TransactionHeader_p."LSDX NCF", true, TransactionHeader_p."Receipt No.")
        end;

        if not IsSuccess and not TransactionHeader_p."LSEF Has Contingencies" then begin
            Evaluate(TransactionHeader_p."LSEF e-NCF Type", CopyStr(TransactionHeader_p."LSDX NCF", 2, 2));
            LscPOSTerminal.Get(TransactionHeader_p."POS Terminal No.");

            case TransactionHeader_p."LSEF e-NCF Type" of
                "EF eCFType"::"E31 Fiscal Credit Invoice":
                    TransactionHeader_p."LSEF Alternal NCF Serial No." := LscPOSTerminal."LSEF Alternal NCF SerialNo CRF";
                "EF eCFType"::"E32 Final Consumer Invoice":
                    TransactionHeader_p."LSEF Alternal NCF Serial No." := LscPOSTerminal."LSEF Alternal NCF SerialNo CF";
                "EF eCFType"::"E34 Credit Memo":
                    TransactionHeader_p."LSEF Alternal NCF Serial No." := LscPOSTerminal."LSEF Alternal NCF SerialNo NC";
                "EF eCFType"::"E44 Free Zone":
                    TransactionHeader_p."LSEF Alternal NCF Serial No." := LscPOSTerminal."LSEF Alternal NCF SerialNo ESP";
                "EF eCFType"::"E45 Government":
                    TransactionHeader_p."LSEF Alternal NCF Serial No." := LscPOSTerminal."LSEF Alternal NCF SerialNo GUB";
            end;
            TransactionHeader_p."LSEF Has Contingencies" := true;
            TransactionHeader_p."LSEF Alternal NCF" := NoSeriesManagement.GetNextNo(TransactionHeader_p."LSEF Alternal NCF Serial No.", Today(), true);
            TransactionHeader_p.Modify(false);
        end;

        if IsSuccess then begin
            TransactionHeader_p.SetRecFilter();
            if TransactionHeader_p.FindLast() then
                LSEFElectronicPOSUtility.InitQRArguments(TransactionHeader_p);

            EfProcessRequest.SetRange("LSEF Store No.", TransactionHeader_p."Store No.");
            EfProcessRequest.SetRange("LSEF POS Terminal No.", TransactionHeader_p."POS Terminal No.");
            EfProcessRequest.SetRange("Document No.", TransactionHeader_p."Receipt No.");
            if EfProcessRequest.FindLast() then
                if EfProcessRequest.Delete(true) then;
        end;

        exit(IsSuccess);
    end;
    #endregion

    procedure SendXmlElectronicDocument(pXmlDocumentText: Text; referencia: Code[20]; isE32Resumen: Boolean; DocumentNo: Code[20]): Boolean
    var
        EfProcessRequestList: Record "EF Process Request";
        LscTransactionHeader: Record "LSC Transaction Header";
        ecfType: Code[2];
        EnvelopeDocument: XmlDocument;
        ResponseDocument: XmlDocument;
        RootElementNode: XmlElement;
        EncabezadoAreaNode: XmlElement;
        BodyAreaNode: XmlElement;
        ConsultaAreaNode: XmlElement;
        DocXmlDeclaration: XmlDeclaration;
        FileXml: XmlDocument;
        FileNode: XmlNode;
        FieldCaption: Text;
        FieldXMLText: XmlText;
        ChildNode: XmlElement;
        soapPrefixLbl: Label 'soapenv';
        namespaceUrlLbl: Label 'http://schemas.xmlsoap.org/soap/envelope/';
        cofPrefixLbl: Label 'cof';
        cofnamespaceUrlLbl: Label 'http://www.cofidi.com.mx/';
        lXMLText: Text;
        lXMLTextRequest: Text;
        HttpClientRequest: HttpClient;
        HttpContentInfo: HttpContent;
        HttpHeaderContent: HttpHeaders;
        HttpResponseMessageInfo: HttpResponseMessage;
        IsSuccess: Boolean;
        RequestBodyXml: XmlDocument;
        FailRequestErr: Label 'Http request failed with status %1 code, %2', Comment = '%1 = HttpStatusCode, %2 = HttpStatusMessage';
        CaptionLbl: Label '%1%2.xml', Comment = '%1 = Doc Type, %2 ECF';
        CaptionText: Text[50];
        IsHandled: Boolean;
        SourceType: Option Sales,Purchase,POS;
    begin
        if CopyStr(referencia, 1, 1) = 'B' then exit(false);

        if not EfAdministrationSetup.Get() then exit(false);
        if not EfAdministrationSetup."LSEF Use Elec. Service On POS" then exit(false);
        if not EfSoapDocument.ValidateMandatoryFields(EfAdministrationSetup) then exit(false);
        //TODO: AQUI PUDIERAMOS CREAR EL REGISTRO DE LA TABLA PROCESS REQUEST
        SourceType := SourceType::POS;
        ecfType := CopyStr(referencia, 2, 2);
        EnvelopeDocument := XmlDocument.Create();
        DocXmlDeclaration := XmlDeclaration.Create('1.0', 'UTF-8', 'no');
        EnvelopeDocument.SetDeclaration(DocXmlDeclaration);
        RootElementNode := XmlElement.Create('Envelope', namespaceUrlLbl);
        RootElementNode.Add(XmlAttribute.CreateNamespaceDeclaration(cofPrefixLbl, cofnamespaceUrlLbl));
        RootElementNode.Add(XmlAttribute.CreateNamespaceDeclaration(soapPrefixLbl, namespaceUrlLbl));
        EnvelopeDocument.Add(RootElementNode);
        EncabezadoAreaNode := XmlElement.Create('Header', namespaceUrlLbl);

        RootElementNode.Add(EncabezadoAreaNode);

        BodyAreaNode := XmlElement.Create('Body', namespaceUrlLbl);

        ConsultaAreaNode := XmlElement.Create('GeneraCFD', cofnamespaceUrlLbl);

        //Add Track Id
        FieldCaption := 'Empresa';
        ChildNode := XmlElement.Create(FieldCaption, cofnamespaceUrlLbl);
        if isE32Resumen then
            FieldXMLText := XmlText.Create(EfAdministrationSetup."Company ID Final Consumer")
        else
            FieldXMLText := XmlText.Create(EfAdministrationSetup."Company ID");
        ChildNode.Add(FieldXMLText);
        ConsultaAreaNode.Add(ChildNode);

        //Add Usuario
        FieldCaption := 'Usuario';
        ChildNode := XmlElement.Create(FieldCaption, cofnamespaceUrlLbl);
        FieldXMLText := XmlText.Create(EfAdministrationSetup."User Name");
        ChildNode.Add(FieldXMLText);
        ConsultaAreaNode.Add(ChildNode);

        //Add Pwd
        FieldCaption := 'Pwd';
        ChildNode := XmlElement.Create(FieldCaption, cofnamespaceUrlLbl);
        FieldXMLText := XmlText.Create(EfAdministrationSetup."User Password");
        ChildNode.Add(FieldXMLText);
        ConsultaAreaNode.Add(ChildNode);

        //Add Archivo
        if EfAdministrationSetup."Send File as XML" then begin
            FieldCaption := 'Archivo';
            if XmlDocument.ReadFrom(pXmlDocumentText, FileXml) then begin
                ChildNode := XmlElement.Create(FieldCaption, cofnamespaceUrlLbl);
                //FileCData := XmlCData.Create(pXmlDocumentText);
                //ChildNode.Add(FileCData);
                if FileXml.SelectSingleNode('ECF', FileNode) then
                    ChildNode.Add(FileNode.AsXmlElement())
                else
                    Error('Error');
                ConsultaAreaNode.Add(ChildNode);
            end else begin
                ChildNode := XmlElement.Create(FieldCaption, cofnamespaceUrlLbl);
                FieldXMLText := XmlText.Create(pXmlDocumentText);
                ChildNode.Add(FieldXMLText);
                ConsultaAreaNode.Add(ChildNode);
            end;

        end else begin
            FieldCaption := 'Archivo';
            ChildNode := XmlElement.Create(FieldCaption, cofnamespaceUrlLbl);
            FieldXMLText := XmlText.Create(pXmlDocumentText);
            ChildNode.Add(FieldXMLText);
            ConsultaAreaNode.Add(ChildNode);
        end;

        //Add Tipo
        FieldCaption := 'Tipo';
        ChildNode := XmlElement.Create(FieldCaption, cofnamespaceUrlLbl);
        FieldXMLText := XmlText.Create('02');
        ChildNode.Add(FieldXMLText);
        ConsultaAreaNode.Add(ChildNode);

        //Add Tipo
        FieldCaption := 'Referencia';
        ChildNode := XmlElement.Create(FieldCaption, cofnamespaceUrlLbl);
        FieldXMLText := XmlText.Create(referencia);
        ChildNode.Add(FieldXMLText);
        ConsultaAreaNode.Add(ChildNode);

        BodyAreaNode.Add(ConsultaAreaNode);
        RootElementNode.Add(BodyAreaNode);
        EnvelopeDocument.WriteTo(lXMLTextRequest);

        if EfAdministrationSetup."Downloads Requests" then
            if XmlDocument.ReadFrom(lXMLTextRequest, RequestBodyXml) then begin
                CaptionText := StrSubstNo(CaptionLbl, 'Request_ECF', referencia);

                EfSoapDocument.DownloadDocument(RequestBodyXml, CaptionText);
            end;
        OnBeforeSendRequest(DocumentNo, referencia, lXMLTextRequest, IsHandled);

        if IsHandled then
            exit(IsHandled)
        else begin
            HttpContentInfo.WriteFrom(lXMLTextRequest);
            HttpContentInfo.GetHeaders(HttpHeaderContent);
            HttpHeaderContent.Remove('Content-Type');
            HttpHeaderContent.Add('Content-Type', 'text/xml;charset=utf-8');
            HttpHeaderContent.Add('cofidi4_wsSoap', 'GeneraCFD');

            HttpClientRequest.SetBaseAddress(EfAdministrationSetup."URL Endpoint");
            HttpClientRequest.DefaultRequestHeaders.Add('User-Agent', 'Dynamics 365');
            if HttpClientRequest.Post('', HttpContentInfo, HttpResponseMessageInfo) then
                if HttpResponseMessageInfo.IsSuccessStatusCode() then begin
                    lXMLText := '';
                    if HttpResponseMessageInfo.HttpStatusCode = 200 then begin
                        if HttpResponseMessageInfo.Content.ReadAs(lXMLText) then begin
                            IsSuccess := true;
                            if XmlDocument.ReadFrom(lXMLText, ResponseDocument) then begin
                                IsSuccess := true;
                                IsSuccess := ProcessDocumentResponse(lXMLText, referencia, DocumentNo, lXMLTextRequest);
                            end
                            else
                                exit(false);
                        end;
                    end else begin
                        IsSuccess := false;
                        Clear(LscTransactionHeader);
                        LscTransactionHeader.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.");
                        LscTransactionHeader.SetRange("Receipt No.", DocumentNo);
                        LscTransactionHeader.SetRange("LSDX NCF", referencia);
                        if LscTransactionHeader.FindFirst() then begin
                            EfProcessRequestList.Reset();
                            EfProcessRequestList.SetCurrentKey("Document No.", "LSEF Store No.", "LSEF POS Terminal No.");
                            EfProcessRequestList.SetRange("Document No.", DocumentNo);
                            EfProcessRequestList.SetRange("LSEF Store No.", LscTransactionHeader."Store No.");
                            EfProcessRequestList.SetRange("LSEF POS Terminal No.", LscTransactionHeader."POS Terminal No.");
                            if not EfProcessRequestList.FindFirst() then begin
                                EfProcessRequestList.Init();
                                EfProcessRequestList."LSEF Store No." := LscTransactionHeader."Store No.";
                                EfProcessRequestList."LSEF POS Terminal No." := LscTransactionHeader."POS Terminal No.";
                                EfProcessRequestList."Document No." := DocumentNo;
                                EfProcessRequestList."EFC Type" := EfSoapDocument.GeteCFTypeFromString(ecfType);
                                EfProcessRequestList."ECF Fiscal" := CopyStr(referencia, 1, 13);
                                EfProcessRequestList."LSEF Date" := LscTransactionHeader.Date;
                                EfProcessRequestList."ECF Posting Date" := LscTransactionHeader.Date;
                                EfProcessRequestList."EF Source Code Type" := EfProcessRequestList."EF Source Code Type"::POS;
                                EfProcessRequestList.Insert(true);
                            end else begin
                                EfProcessRequestList.Sent := false;
                                EfProcessRequestList."ECF Fiscal" := CopyStr(referencia, 1, 13);
                                EfProcessRequestList."EFC Type" := EfSoapDocument.GeteCFTypeFromString(ecfType);
                                LscTransactionHeader."LSEF Has Contingencies" := true;
                                LscTransactionHeader.Modify(false);
                            end;
                        end;

                        exit(IsSuccess);
                    end;

                    exit(IsSuccess);
                end else begin
                    lXMLText := '';
                    if HttpResponseMessageInfo.Content.ReadAs(lXMLText) then begin
                        IsSuccess := false;
                        Clear(LscTransactionHeader);
                        LscTransactionHeader.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.");
                        LscTransactionHeader.SetRange("Receipt No.", DocumentNo);
                        LscTransactionHeader.SetRange("LSDX NCF", referencia);

                        if LscTransactionHeader.FindFirst() then begin
                            EfProcessRequestList.Reset();
                            EfProcessRequestList.SetCurrentKey("Document No.", "LSEF Store No.", "LSEF POS Terminal No.");
                            EfProcessRequestList.SetRange("Document No.", DocumentNo);
                            EfProcessRequestList.SetRange("LSEF Store No.", LscTransactionHeader."Store No.");
                            EfProcessRequestList.SetRange("LSEF POS Terminal No.", LscTransactionHeader."POS Terminal No.");
                            if not EfProcessRequestList.FindFirst() then begin
                                EfProcessRequestList.Init();
                                EfProcessRequestList."LSEF Store No." := LscTransactionHeader."Store No.";
                                EfProcessRequestList."LSEF POS Terminal No." := LscTransactionHeader."POS Terminal No.";
                                EfProcessRequestList."Document No." := DocumentNo;
                                EfProcessRequestList."EFC Type" := EfSoapDocument.GeteCFTypeFromString(ecfType);
                                EfProcessRequestList."ECF Fiscal" := CopyStr(referencia, 1, 13);
                                EfProcessRequestList."LSEF Date" := LscTransactionHeader.Date;
                                EfProcessRequestList."ECF Posting Date" := LscTransactionHeader.Date;
                                EfProcessRequestList."EF Source Code Type" := EfProcessRequestList."EF Source Code Type"::POS;
                                EfProcessRequestList.Insert(true);
                                Error(FailRequestErr, Format(HttpResponseMessageInfo.HttpStatusCode), HttpResponseMessageInfo.ReasonPhrase);
                            end else begin
                                EfProcessRequestList.Sent := false;
                                EfProcessRequestList."ECF Fiscal" := CopyStr(referencia, 1, 13);
                                EfProcessRequestList."EFC Type" := EfSoapDocument.GeteCFTypeFromString(ecfType);
                                LscTransactionHeader."LSEF Has Contingencies" := true;
                                LscTransactionHeader.Modify(false);
                            end;
                        end;
                    end;
                end;
        end;
        OnAfterSendXmlElectronicDocument(IsSuccess, CopyStr(referencia, 1, 19), DocumentNo, SourceType);
        exit(IsSuccess);
    end;

    procedure ProcessDocumentResponse(DocumentResponse: Text; referencia: Code[20]; DocumentNo: Code[20]; lXMLTextRequest: Text): Boolean
    var
        EfAdministrationSetup: Record "EF Administration Setup";
        localLscTransactionHeader: Record "LSC Transaction Header";
        EfResponseDocuments: Record "EF Response Documents";
        ProcessRequestList: Record "EF Process Request";
        EfProcessRequest: Record "EF Process Request";
        Base64Convert: Codeunit "Base64 Convert";
        EfLogMessages: Record "EF Log Message";
        XMLInStream: InStream;
        DialogCaption: Text;
        XMLFileName: Text;
        xmlDoc: XmlDocument;
        ResponseDocument: XmlDocument;
        XmlNamesepaceManager: XmlNamespaceManager;
        ResultNodeList: XmlNodeList;
        ResultNode: XmlNode;
        XmlNode2: XmlNode;
        AttributeNode: XmlNode;
        lXMLText: Text;
        IsSuccess: Boolean;
        cofnamespaceUrlLbl: Label 'http://www.cofidi.com.mx/';
        RespuestaInvoiceNode: XmlNode;
        FolioInterno: Code[19];
        eCFType: Code[2];
        FolioFiscal: Code[19];
        Status: Code[10];
        CertificateNo: Code[50];
        FechaHoraExpedicionString: Text[50];
        ResponseCode: Code[20];
        TrackId: Text[150];
        FileType: Text[10];
        FileContent: Text;
        FileContentConverted: Text;
        FileInstream: InStream;
        FileDocument: XmlDocument;
        FileOutStream: OutStream;
        ResendRequest: Boolean;
        ModifyProcessRequestList: Boolean;
        CaptionLbl: Label '%1%2.xml', Comment = '%1 = Doc Type, %2 ECF';
        GeneraCFDResponseErr: Label 'No GeneraCFDResponse Node was received';
        RespuestaINVOICEErr: Label 'No Respuesta/INVOICE Node Was received';
        CaptionText: Text[50];
        XmlResponseDocument: XmlDocument;
        XmlRespuestaInvoiceNode: XmlNode;

    begin
        IsSuccess := false;
        localLscTransactionHeader.Reset();
        localLscTransactionHeader.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.");
        localLscTransactionHeader.SetRange("Receipt No.", DocumentNo);
        localLscTransactionHeader.FindFirst();

        ProcessRequestList.Reset();
        ProcessRequestList."Document No." := DocumentNo;
        ProcessRequestList."LSEF Date" := localLscTransactionHeader.Date;
        if DocumentResponse <> '' then
            XmlDocument.ReadFrom(DocumentResponse, xmlDoc)
        else begin
            UploadIntoStream(DialogCaption, '', '', XMLFileName, XMLInStream);
            XmlDocument.ReadFrom(XMLInStream, xmlDoc);
        end;

        EfAdministrationSetup.Get();
        if EfAdministrationSetup."Downloads Response" then begin
            CaptionText := StrSubstNo(CaptionLbl, 'Response_', referencia);
            EfSoapDocument.DownloadDocument(xmlDoc, CaptionText);
        end;

        EfProcessRequest."LSEF Store No." := localLscTransactionHeader."Store No.";
        EfProcessRequest."LSEF POS Terminal No." := localLscTransactionHeader."POS Terminal No.";
        EfProcessRequest."Document No." := localLscTransactionHeader."Receipt No.";
        EfProcessRequest."ECF Posting Date" := localLscTransactionHeader.Date;

        XmlNamesepaceManager.AddNamespace('res', cofnamespaceUrlLbl);
        if xmlDoc.SelectNodes('//res:GeneraCFDResponse', XmlNamesepaceManager, ResultNodeList) then begin
            lXMLText := '';
            foreach ResultNode in ResultNodeList do
                if ResultNode.SelectSingleNode('res:GeneraCFDResult', XmlNamesepaceManager, XmlNode2) then begin
                    Clear(ResponseDocument);
                    Clear(lXMLText);
                    lXMLText := XmlNode2.AsXmlElement().InnerText();

                    XmlDocument.ReadFrom(lXMLText, ResponseDocument);
                    if ResponseDocument.SelectSingleNode('//Respuesta/INVOICE', RespuestaInvoiceNode) then begin
                        IsSuccess := true;
                        EfResponseDocuments.Init();

                        if RespuestaInvoiceNode.SelectSingleNode('//@TipoDeComprobante', AttributeNode) then begin
                            eCFType := CopyStr(AttributeNode.AsXmlAttribute().Value(), 1, 2);
                            if eCFType <> '' then begin
                                EfProcessRequest."EFC Type" := EfSoapDocument.GeteCFTypeFromString(eCFType);
                                if eCFType = 'RF' then
                                    EfProcessRequest."EFC Type" := EfProcessRequest."EFC Type"::"E32 Final Consumer Invoice";
                            end
                            else
                                EfProcessRequest."EFC Type" := EfSoapDocument.GeteCFTypeFromString(CopyStr(referencia, 2, 2));
                        end else
                            IsSuccess := false;

                        if RespuestaInvoiceNode.SelectSingleNode('//@status', AttributeNode) then begin
                            Status := CopyStr(AttributeNode.AsXmlAttribute().Value(), 1, 10);
                            EfProcessRequest.Status := Status;
                            EfResponseDocuments."Response Status" := Status;
                        end;

                        if RespuestaInvoiceNode.SelectSingleNode('//@folio_fiscal', AttributeNode) then begin
                            FolioFiscal := CopyStr(AttributeNode.AsXmlAttribute().Value(), 1, 19);
                            if (EfProcessRequest."ECF Fiscal" = '') and IsSuccess then
                                EfProcessRequest."ECF Fiscal" := CopyStr(FolioFiscal, 1, 13);
                        end
                        else
                            IsSuccess := false;

                        if RespuestaInvoiceNode.SelectSingleNode('//@noCertificado', AttributeNode) then begin
                            CertificateNo := CopyStr(AttributeNode.AsXmlAttribute().Value(), 1, 50);
                            EfProcessRequest."Certificate No." := CertificateNo;
                        end;


                        if RespuestaInvoiceNode.SelectSingleNode('//@code', AttributeNode) then begin
                            ResponseCode := CopyStr(AttributeNode.AsXmlAttribute().Value(), 1, 20);
                            EfProcessRequest.Code := ResponseCode;
                            EfResponseDocuments."Response Code" := ResponseCode;
                        end;

                        EfResponseDocuments."Reception Date" := Today();
                        EfResponseDocuments."Document No." := localLscTransactionHeader."Receipt No.";
                        if not EfResponseDocuments.Insert(true) then
                            if not EfResponseDocuments.Modify(true) then;

                    end else begin
                        EfLogMessages.Init();
                        EfLogMessages.Code := CopyStr(referencia, 1, 10);
                        EfLogMessages.Status := '502';
                        EfLogMessages."Error Message" := RespuestaINVOICEErr;
                        EfLogMessages.Insert(true);
                    end;

                    if ResponseDocument.SelectSingleNode('//Respuesta/CFDTimbre', RespuestaInvoiceNode) then
                        if eCFType <> 'RF' then
                            if RespuestaInvoiceNode.SelectSingleNode('//@UUID', AttributeNode) then begin
                                TrackId := CopyStr(AttributeNode.AsXmlAttribute().Value(), 1, 150);
                                EfProcessRequest."EFC Track ID" := TrackId;
                                EfResponseDocuments."EFC Track ID" := EfProcessRequest."EFC Track ID";
                            end else
                                IsSuccess := false;


                    if ResponseDocument.SelectSingleNode('//Respuesta/CFDArchivos', RespuestaInvoiceNode) then begin

                        if RespuestaInvoiceNode.SelectSingleNode('//@Tipo', AttributeNode) then
                            FileType := CopyStr(AttributeNode.AsXmlAttribute().Value(), 1, 10);

                        if RespuestaInvoiceNode.SelectSingleNode('//@Archivo', AttributeNode) then begin
                            FileContent := AttributeNode.AsXmlAttribute().Value();
                            EfProcessRequest."XML File".CreateInStream(FileInstream);
                            EfProcessRequest."XML File".CreateOutStream(FileOutStream);
                            FileContentConverted := Base64Convert.FromBase64(FileContent);
                            FileOutStream.WriteText(FileContentConverted);

                            Clear(XmlResponseDocument);
                            if (XmlDocument.ReadFrom(FileContentConverted, XmlResponseDocument)) then
                                if XmlResponseDocument.SelectSingleNode('//ECF/FechaHoraFirma', XmlRespuestaInvoiceNode) then
                                    EfProcessRequest."Signed Date" := CopyStr(XmlRespuestaInvoiceNode.AsXmlElement().InnerText(), 1, 20);


                            if not EfProcessRequest.Insert(true) then
                                if EfProcessRequest.Modify(true) then;


                            if XmlDocument.ReadFrom(FileContentConverted, FileDocument) then begin
                                if eCFType = 'RF' then
                                    ProcessRFCE(FileDocument, EfProcessRequest, ResendRequest)
                                else
                                    ProcessECF(FileDocument, EfProcessRequest, ResendRequest);
                            end else
                                if XmlDocument.ReadFrom(FileInstream, FileDocument) then
                                    if eCFType = 'RF' then
                                        ProcessRFCE(FileDocument, EfProcessRequest, ResendRequest)
                                    else
                                        ProcessECF(FileDocument, EfProcessRequest, ResendRequest);

                            IsSuccess := true;

                        end;

                    end
                    else begin
                        EfAdministrationSetup.Get();
                        if EfAdministrationSetup."Download Logs Exceptions" then begin
                            CaptionText := StrSubstNo(CaptionLbl, 'Exception_Response_', EfProcessRequest."ECF Fiscal");
                            EfSoapDocument.DownloadDocument(ResponseDocument, CaptionText);
                        end;

                        ProcessException(ResponseDocument, EfProcessRequest);
                        IsSuccess := false;
                    end;

                    if not IsSuccess then begin
                        localLscTransactionHeader.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.");
                        localLscTransactionHeader.SetRange("Receipt No.", DocumentNo);
                        localLscTransactionHeader.FindLast();

                        ProcessRequestList."ECF Fiscal" := CopyStr(referencia, 1, 13);
                        ProcessRequestList."EFC Type" := EfSoapDocument.GeteCFTypeFromString(CopyStr(referencia, 2, 2));
                        ProcessRequestList.Sent := false;
                        ProcessRequestList."LSEF Store No." := localLscTransactionHeader."Store No.";
                        ProcessRequestList."LSEF POS Terminal No." := localLscTransactionHeader."POS Terminal No.";
                        ProcessRequestList."EF Source Code Type" := ProcessRequestList."EF Source Code Type"::POS;
                        ProcessRequestList."LSEF Date" := localLscTransactionHeader.Date;
                        ProcessRequestList."ECF Posting Date" := localLscTransactionHeader.Date;

                        if not ProcessRequestList.Insert(true) then
                            if ProcessRequestList.Modify(true) then;

                    end;
                end;

        end
        else begin
            EfLogMessages.Init();
            EfLogMessages.Code := CopyStr(DocumentNo, 1, 10);
            EfLogMessages.Status := '501';
            EfLogMessages."Error Message" := GeneraCFDResponseErr;
            EfLogMessages.Insert(true);
        end;

        exit(IsSuccess);
    end;

    procedure ProcessECF(xmlDocumentInput: XmlDocument; var EfProcessRequest: Record "EF Process Request"; ResendRequest: Boolean)
    var
        localLscTransactionHeader: Record "LSC Transaction Header";
        EfLogMessages: Record "EF Log Message";
        LscPosSession: Codeunit "LSC POS Session";
        rOutStream: OutStream;
        eNcf: Code[13];
        tipoeCF: Code[2];
        DocumentNo: Code[20];
        SignatureValue: Text;
        SignatureDocNode: XmlNode;
        SignatureValueErr: Label 'No Signature Value was received';
    begin
        //ECF/Signature no se encuentra //*[local-name()='Signature']

        if xmlDocumentInput.SelectSingleNode('//ECF/Encabezado/IdDoc/TipoeCF', SignatureDocNode) then
            tipoeCF := CopyStr(SignatureDocNode.AsXmlElement().InnerText(), 1, 2);


        if xmlDocumentInput.SelectSingleNode('//ECF/Encabezado/IdDoc/eNCF', SignatureDocNode) then begin
            eNcf := CopyStr(SignatureDocNode.AsXmlElement().InnerText(), 1, 13);
            EfProcessRequest."ECF Fiscal" := eNcf;
        end;

        if xmlDocumentInput.SelectSingleNode('//*[local-name()=''SignatureValue'']', SignatureDocNode) then
            SignatureValue := SignatureDocNode.AsXmlElement().InnerText()
        else begin
            EfLogMessages.Init();
            EfLogMessages.Code := CopyStr(EfProcessRequest."Document No.", 1, 10);
            EfLogMessages.Status := '503 - ' + tipoeCF;
            EfLogMessages."Error Message" := SignatureValueErr;
            EfLogMessages.Insert(true);
        end;

        EfProcessRequest."EF Source Code Type" := EfProcessRequest."EF Source Code Type"::POS;
        Clear(localLscTransactionHeader);
        Clear(rOutStream);
        localLscTransactionHeader.SetCurrentKey("Store No.", "POS Terminal No.", "Receipt No.");
        localLscTransactionHeader.SetRange("Store No.", EfProcessRequest."LSEF Store No.");
        localLscTransactionHeader.SetRange("POS Terminal No.", EfProcessRequest."LSEF POS Terminal No.");
        localLscTransactionHeader.SetRange("Receipt No.", EfProcessRequest."Document No.");
        if localLscTransactionHeader.FindLast() then begin
            localLscTransactionHeader."LSEF Signature Value".CreateOutStream(rOutStream);
            localLscTransactionHeader."LSEF Stamped Date/Time" := EfProcessRequest."Signed Date";
            localLscTransactionHeader."LSEF Security Code" := CopyStr(SignatureValue, 1, 6);
            rOutStream.WriteText(SignatureValue);

            localLscTransactionHeader."LSEF Has Contingencies" := false;
            if localLscTransactionHeader.Modify(false) then;

            if not EfProcessRequest.Insert(true) then
                if EfProcessRequest.Modify(true) then;
        end;

    end;

    local procedure GeteCFTypeFromString(eCFTypeCode: Code[2]): Enum "EF eCFType"
    begin
        case eCFTypeCode of
            '31':
                exit("EF eCFType"::"E31 Fiscal Credit Invoice");
            '32':
                exit("EF eCFType"::"E32 Final Consumer Invoice");
            '33':
                exit("EF eCFType"::"E33 Debit Note");
            '34':
                exit("EF eCFType"::"E34 Credit Memo");
            '41':
                exit("EF eCFType"::"E41 Purchase");
            '43':
                exit("EF eCFType"::"E43 Minor Expenses");
            '44':
                exit("EF eCFType"::"E44 Free Zone");
            '45':
                exit("EF eCFType"::"E45 Government");
            '46':
                exit("EF eCFType"::"E46 Export Voucher ");
            '47':
                exit("EF eCFType"::"E47 Foreign Payment");
        end;
    end;

    procedure ProcessException(xmlDocumentInput: XmlDocument; var EfProcessRequest: Record "EF Process Request")
    var
        localLscTransactionHeader: Record "LSC Transaction Header";
        rOutStream: OutStream;
        eNcf: Code[13];
        ExceptionDocNode: XmlNode;
        AttributeNode: XmlNode;
        XMLInStream: InStream;
        XMLFileName: Text;
        DialogCaption: Text;
        Test: Boolean;
        DocType: Code[2];
        ExceptionMsg: Label 'An Exception has occured processing Electronic Request on Invoice No. %1, Msg. %2', Comment = '%1 = Invoice No., %2 = Exception Message';
        ExceptionMessage: Text;
    begin

        if xmlDocumentInput.SelectSingleNode('//Respuesta/INVOICE', ExceptionDocNode) then begin

            if ExceptionDocNode.SelectSingleNode('//@FolioInterno', AttributeNode) then begin
                eNcf := CopyStr(AttributeNode.AsXmlAttribute().Value(), 1, 13);
                EfProcessRequest."ECF Fiscal" := eNcf;
            end;

            if ExceptionDocNode.SelectSingleNode('//@TipoDeComprobante', AttributeNode) then begin
                DocType := CopyStr(AttributeNode.AsXmlAttribute().Value(), 1, 2);
                EfProcessRequest."EFC Type" := GeteCFTypeFromString(DocType);
            end;

            if ExceptionDocNode.SelectSingleNode('//@status', AttributeNode) then
                EfProcessRequest.Status := CopyStr(AttributeNode.AsXmlAttribute().Value(), 1, 10);

            if ExceptionDocNode.SelectSingleNode('//@code', AttributeNode) then
                EfProcessRequest.Code := CopyStr(AttributeNode.AsXmlAttribute().Value(), 1, 20);

            if ExceptionDocNode.SelectSingleNode('//@error_message', AttributeNode) then
                ExceptionMessage := AttributeNode.AsXmlAttribute().Value();

        end;

        Clear(rOutStream);
        EfProcessRequest."XML File".CreateOutStream(rOutStream);
        xmlDocumentInput.WriteTo(rOutStream);

        EfProcessRequest."Signed Date" := '';
        EfProcessRequest."Stamped Date" := 0D;
        EfProcessRequest."EF Source Code Type" := EfProcessRequest."EF Source Code Type"::POS;


        // Clear(localLscTransactionHeader);
        // localLscTransactionHeader.SetCurrentKey("LSDX NCF");
        // localLscTransactionHeader.SetRange("Receipt No.", EfProcessRequest."Document No.");
        // if localLscTransactionHeader.FindLast() then begin
        //     EfProcessRequest."Document No." := localLscTransactionHeader."Receipt No.";
        //     if not EfProcessRequest.Insert(true) then
        //         if EfProcessRequest.Modify(true) then;
        // end;

        if not EfProcessRequest.Insert(true) then
            if EfProcessRequest.Modify(true) then;

        Message(StrSubstNo(ExceptionMsg, EfProcessRequest."Document No.", ExceptionMessage));

    end;

    procedure ValidElectronicCustomer(Customer: Record Customer)
    var
        DxNcfSalesSetup: Record "DXNCF Sales Setup";
        NoConfigurationOnNcfSalesSetupErr: Label 'There is no Configuration for Customer %1 on Table %2', Comment = '%1 = Customer No., %2 = DXNCF Sales Setup Table Name';
    begin
        Customer.TestField(Address);
        Customer.TestField("Service Zone Code");
        Customer.TestField("E-Mail");
        Customer.TestField("EF DR County Code");
        Customer.TestField("EF DR Township Code");
        Customer.TestField("DxTipo NCF");
        Customer.TestField("DxUtiliza NCF", true); // TODO: JAM: Me parece esto no es necesario.

        if DxNcfSalesSetup.Get(Customer."DxTipo NCF") then begin
            DxNcfSalesSetup.TestField("No. Serie NCF Fact.");
            DxNcfSalesSetup.TestField("No. Serie NCF NCR");
            DxNcfSalesSetup.TestField("Tipo NCF");
        end else
            Error(NoConfigurationOnNcfSalesSetupErr, Customer."No.", DxNcfSalesSetup.TableCaption());


    end;

    procedure ValidRetailItemForElectronic(Item: Record Item)
    var
        UnitofMeasure: Record "Unit of Measure";
        VatPostingSetup: Record "VAT Posting Setup";
        NoVatSetupErr: Label 'There is no VAT Setup for %1 - %2', Comment = '%1 VAT. Bus Posting Group, %2 = VAT Gen. Posting Group';
        NoUnitOfMeasureConfiguredErr: Label '%1 is not configured on table %2', Comment = '%1 EF UOM Type Option, %2 = Unit of Measure Table';
    begin

        Item.TestField("Base Unit of Measure");
        Item.TestField("Sales Unit of Measure");
        Item.TestField("Purch. Unit of Measure");
        Item.TestField("VAT Bus. Posting Gr. (Price)");
        Item.TestField("VAT Prod. Posting Group");
        if not UnitofMeasure.Get(Item."Base Unit of Measure") then
            Error(NoUnitOfMeasureConfiguredErr, Item."Base Unit of Measure", UnitofMeasure.TableCaption());

        UnitofMeasure.Reset();

        if not UnitofMeasure.Get(Item."Sales Unit of Measure") then
            Error(NoUnitOfMeasureConfiguredErr, Item."Sales Unit of Measure", UnitofMeasure.TableCaption());

        UnitofMeasure.Reset();

        if not UnitofMeasure.Get(Item."Purch. Unit of Measure") then
            Error(NoUnitOfMeasureConfiguredErr, Item."Base Unit of Measure", UnitofMeasure.TableCaption());

        if not VatPostingSetup.Get(Item."VAT Bus. Posting Gr. (Price)", Item."VAT Prod. Posting Group") then
            Error(NoVatSetupErr, Item."VAT Bus. Posting Gr. (Price)", Item."VAT Prod. Posting Group");

        VatPostingSetup.TestField("EF Tax Indicator");
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeSendRequest(var InvoiceNo: Code[20]; var referencia: Code[20]; var lXMLText: Text; var IsHandled: Boolean)
    begin

    end;

    procedure InitQRArguments(var pLscTransactionHeader: Record "LSC Transaction Header"; var pEncodedBarcode: Text)
    var
        initCompanyInformation: Record "Company Information";
        LscRetailImageLink: Record "LSC Retail Image Link";
        LscRetailImage: Record "LSC Retail Image";
        DxInstream: InStream;
        localOutStream: OutStream;
        isInStream: InStream;
        SigValue: Text;
        qrCodeGen: Text;
        pngFile: Text;
        converted64: Text;
        //-
        RncComprador: Text[15];
        eNCF: Text[13];
        fechEmision: Date;
        MontoTotal: Decimal;
        fechaFirma: Text[20];
        securityCode: Text[6];
        Base64QRText: Text;
        TempBlob: Codeunit "Temp Blob";
        QROutStream: OutStream;
    begin
        EfAdministrationSetup.Get();
        initCompanyInformation.Get();

        RncComprador := CopyStr(pLscTransactionHeader."LSDX RNC/Cedula", 1, 15);
        eNCF := CopyStr(pLscTransactionHeader."LSDX NCF", 1, 13);
        fechEmision := pLscTransactionHeader.Date;
        MontoTotal := Abs(pLscTransactionHeader."Gross Amount");
        fechaFirma := pLscTransactionHeader."LSEF Stamped Date/Time";
        securityCode := pLscTransactionHeader."LSEF Security Code";

        Base64QRText := EfUtilityManagement.getQRBase64(RncComprador, eNCF, fechEmision, MontoTotal, fechaFirma, securityCode);


    end;


    [IntegrationEvent(false, false)]
    local procedure OnAfterSendXmlElectronicDocument(IsSuccess: Boolean; referencia: Code[19]; InvoiceNo: Code[20]; SourceType: Option Sales,Purchase,POS)
    begin

    end;

    procedure ProcessRFCE(xmlDocumentInput: XmlDocument; var EfProcessRequest: Record "EF Process Request"; ResendRequest: Boolean)
    var
        localLscTransactionHeader: Record "LSC Transaction Header";
        EfLogMessages: Record "EF Log Message";
        LscPosSession: Codeunit "LSC POS Session";
        rOutStream: OutStream;
        eNcf: Code[13];
        tipoeCF: Code[2];
        SignatureValue: Text;
        SignatureDocNode: XmlNode;
        SignatureValueErr: Label 'No Signature Value was received';
    begin

        //ECF/Signature no se encuentra //*[local-name()='Signature']

        if xmlDocumentInput.SelectSingleNode('//RFCE/Encabezado/IdDoc/TipoeCF', SignatureDocNode) then
            tipoeCF := CopyStr(SignatureDocNode.AsXmlElement().InnerText(), 1, 2);


        if xmlDocumentInput.SelectSingleNode('//RFCE/Encabezado/IdDoc/eNCF', SignatureDocNode) then begin
            eNcf := CopyStr(SignatureDocNode.AsXmlElement().InnerText(), 1, 13);
            EfProcessRequest."ECF Fiscal" := eNcf;
        end;


        if xmlDocumentInput.SelectSingleNode('//*[local-name()=''SignatureValue'']', SignatureDocNode) then
            SignatureValue := SignatureDocNode.AsXmlElement().InnerText()
        else begin
            EfLogMessages.Init();
            EfLogMessages.Code := CopyStr(EfProcessRequest."Document No.", 1, 10);
            EfLogMessages.Status := '503 - ' + tipoeCF;
            EfLogMessages."Error Message" := SignatureValueErr;
            EfLogMessages.Insert(true);
        end;

        EfProcessRequest."EF Source Code Type" := EfProcessRequest."EF Source Code Type"::POS;

        Clear(localLscTransactionHeader);
        Clear(rOutStream);
        localLscTransactionHeader.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.");
        localLscTransactionHeader.SetRange("Store No.", LscPosSession.StoreNo());
        localLscTransactionHeader.SetRange("POS Terminal No.", LscPosSession.TerminalNo());
        localLscTransactionHeader.SetRange("Receipt No.", EfProcessRequest."Document No.");
        if localLscTransactionHeader.FindFirst() then begin
            localLscTransactionHeader."LSEF Signature Value".CreateOutStream(rOutStream);
            localLscTransactionHeader."LSEF Stamped Date/Time" := EfProcessRequest."Signed Date";
            localLscTransactionHeader."LSEF Security Code" := CopyStr(SignatureValue, 1, 6);
            rOutStream.WriteText(SignatureValue);
            if localLscTransactionHeader.Modify(false) then
                if ResendRequest then
                    EfProcessRequest.Modify(true)
                else
                    if not EfProcessRequest.Insert(true) then
                        if EfProcessRequest.Modify(true) then;
        end;

    end;
}