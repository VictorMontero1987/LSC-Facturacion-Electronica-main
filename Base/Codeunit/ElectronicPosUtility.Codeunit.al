codeunit 36003102 "LSEF Electronic POS Utility"
{
    trigger OnRun()
    begin

    end;

    var
        EfAdministrationSetup: Record "EF Administration Setup";
        LsdxPosSetup: Record "LSDX POS Setup";
        DXNCFSetup: Record "DXNCF Setup";
        LscPosOposUtility: Codeunit "LSC POS OPOS Utility";
        LscPosGui: Codeunit "LSC POS GUI";

    procedure ValidateDataFiscal(var pLscTransactionHeader: Record "LSC Transaction Header"): Boolean
    var
        IsHandled: Boolean;
    begin
        if not EfAdministrationSetup.Get() then begin
            IsHandled := false;
            exit(IsHandled);
        end;

        if not EfAdministrationSetup."Use Electronic Service" then begin
            IsHandled := false;
            exit(IsHandled);
        end;

        if CopyStr(pLscTransactionHeader."LSDX NCF", 1, 1) <> 'E' then begin
            IsHandled := false;
            exit(IsHandled);
        end;

        if LsdxPosSetup.Get() then
            if LsdxPosSetup."Use POS Localization" then begin
                // DXFISCALPRINTER SAC - Validacion de los campos DXPOS
                DXNCFSetup.Get();

                OnBeforeValidateFiscalData(pLscTransactionHeader, IsHandled);

                if IsHandled then exit(IsHandled);

                CASE pLscTransactionHeader."LSDX Tipo Doc. Fiscal" OF


                    pLscTransactionHeader."LSDX Tipo Doc. Fiscal"::"Final Consumer":
                        BEGIN
                            // Validacion length del NCF que sea 19 de lo contrario lanzar un error
                            IF (STRLEN(pLscTransactionHeader."LSDX NCF") <> DXNCFSetup."Digitos e-CF") THEN BEGIN
                                //ERROR
                                ErrorBeep('Error: Comprobante Cons. Final no tiene el NCF Correcto');
                                EXIT(false);
                            END;


                            IF (pLscTransactionHeader."LSDX RNC/Cedula" <> '') AND (pLscTransactionHeader."LSDX Razon Social" <> '') THEN BEGIN
                                IF ((STRLEN(pLscTransactionHeader."LSDX RNC/Cedula") <> 9) AND (STRLEN(pLscTransactionHeader."LSDX RNC/Cedula") <> 11)) THEN BEGIN
                                    //ERROR
                                    ErrorBeep('Error: Comprobante Cons. Final no tiene RNC correcto del Contribuyente');
                                    EXIT(false);
                                END;

                                IF (pLscTransactionHeader."LSDX Razon Social" = '') THEN BEGIN
                                    //ERROR
                                    ErrorBeep('Error: Comprobante Cons. Final debe llevar Razon Social del Contribuyente');
                                    EXIT(FALSE);
                                END;
                            END

                            ELSE
                                IF (pLscTransactionHeader."LSDX RNC/Cedula" = '') AND (pLscTransactionHeader."LSDX Razon Social" = '') THEN BEGIN
                                    IF (pLscTransactionHeader."LSDX RNC/Cedula" <> '') THEN BEGIN
                                        //ERROR
                                        ErrorBeep('Error: Comprobante Cons. Final no debe tener RNC de contribuyente');
                                        EXIT(FALSE);
                                    END;

                                    IF (pLscTransactionHeader."LSDX Razon Social" <> '') THEN BEGIN
                                        //ERROR
                                        ErrorBeep('Error: Comprobante Cons. Final no debe llevar Razon Social del Contribuyente');
                                        EXIT(FALSE);
                                    END;

                                END;

                            IF (pLscTransactionHeader."LSDX NCF Afectado" <> '') THEN BEGIN
                                //ERROR
                                ErrorBeep('Error: Comprabnte Cons. Final no lleva NCF Afectado');
                                EXIT(FALSE);
                            END;
                            pLscTransactionHeader."LSEF e-NCF Type" := "EF eCFType"::"E32 Final Consumer Invoice";
                        END;


                    pLscTransactionHeader."LSDX Tipo Doc. Fiscal"::"Valid for Fiscal Credit":
                        begin
                            pLscTransactionHeader."LSEF e-NCF Type" := "EF eCFType"::"E31 Fiscal Credit Invoice";
                            // Validacion length del NCF que sea 13 de lo contrario lanzar un error
                            IF (STRLEN(pLscTransactionHeader."LSDX NCF") <> DXNCFSetup."Digitos e-CF") THEN BEGIN
                                //ERROR
                                ErrorBeep('Error: Comprobante Credotp Fiscal no tiene el NCF Correcto');
                                EXIT(FALSE);
                            END

                            // Validacion  del RNC del contribuyente, solo se valida el length
                            ELSE
                                IF ((STRLEN(pLscTransactionHeader."LSDX RNC/Cedula") <> 9) AND (STRLEN(pLscTransactionHeader."LSDX RNC/Cedula") <> 11)) THEN BEGIN
                                    //ERROR
                                    ErrorBeep('Error: Comprobante Credito Fiscal no tiene el RNC Correcto');
                                    EXIT(FALSE);
                                END

                                // Se valida que si tiene el nombre de contribuyente
                                ELSE
                                    IF (pLscTransactionHeader."LSDX Razon Social" = '') THEN BEGIN
                                        //ERROR
                                        ErrorBeep('Error: Comprobante Credito Fiscal debe tener la Razon social del contribuyente');
                                        EXIT(FALSE);
                                    END

                                    // Se valida que no haya un NCF Afectado
                                    ELSE
                                        IF (pLscTransactionHeader."LSDX NCF Afectado" <> '') THEN BEGIN
                                            //ERROR
                                            ErrorBeep('Error: Comprobante Credito Fiscal no lleva NCF Afectado');
                                            EXIT(FALSE);
                                        END;
                        end;
                    pLscTransactionHeader."LSDX Tipo Doc. Fiscal"::"Credit U. Final":
                        BEGIN
                            pLscTransactionHeader."LSEF e-NCF Type" := "EF eCFType"::"E31 Fiscal Credit Invoice";
                            // Validacion length del NCF que sea 19 de lo contrario lanzar un error
                            IF (STRLEN(pLscTransactionHeader."LSDX NCF") <> DXNCFSetup."Digitos e-CF") THEN BEGIN
                                //ERROR
                                ErrorBeep('Error: Comprobante NC Cons. Final no tiene el NCF Correcto');
                                EXIT(FALSE);
                            END;


                            IF (pLscTransactionHeader."LSDX RNC/Cedula" <> '') AND (pLscTransactionHeader."LSDX Razon Social" <> '') THEN BEGIN
                                IF ((STRLEN(pLscTransactionHeader."LSDX RNC/Cedula") <> 9) AND (STRLEN(pLscTransactionHeader."LSDX RNC/Cedula") <> 11)) THEN BEGIN
                                    //ERROR
                                    ErrorBeep('Error: Comprobante Cons. Final no tiene RNC correcto del Contribuyente');
                                    EXIT(FALSE);
                                END;

                                IF (pLscTransactionHeader."LSDX Razon Social" = '') THEN BEGIN
                                    //ERROR
                                    ErrorBeep('Error: Comprobante Cons. Final debe llevar Razon Social del Contribuyente');
                                    EXIT(FALSE);
                                END;
                            END

                            ELSE
                                IF (pLscTransactionHeader."LSDX RNC/Cedula" = '') AND (pLscTransactionHeader."LSDX Razon Social" = '') THEN BEGIN
                                    IF (pLscTransactionHeader."LSDX RNC/Cedula" <> '') THEN BEGIN
                                        //ERROR
                                        ErrorBeep('Error: Comprobante Cons. Final no debe tener RNC de contribuyente');
                                        EXIT(FALSE);
                                    END;

                                    IF (pLscTransactionHeader."LSDX Razon Social" <> '') THEN BEGIN
                                        //ERROR
                                        ErrorBeep('Error: Comprobante Cons. Final no debe llevar Razon Social del Contribuyente');
                                        EXIT(FALSE);
                                    END;

                                END;

                            // Se valida que no haya un NCF Afectado
                            IF (STRLEN(pLscTransactionHeader."LSDX NCF Afectado") <> DXNCFSetup."Digitos e-CF") THEN BEGIN
                                //ERROR
                                ErrorBeep('Error: Comprobante NC Cons. Final no tiene el NCF Afectado Correcto');
                                EXIT(FALSE);
                            END;
                        END;


                    pLscTransactionHeader."LSDX Tipo Doc. Fiscal"::"Credit Note":
                        BEGIN
                            pLscTransactionHeader."LSEF e-NCF Type" := "EF eCFType"::"E34 Credit Memo";
                            pLscTransactionHeader."LSEF NCF Modification Reason" := EfAdministrationSetup."LSEF Def. NC Modification Type"; //TODO: AGREGAR VALIDACION DE ESTE CAMPO ANTES DE REGISTRAR TRANSACCION.
                            // Validacion length del NCF que sea 19 de lo contrario lanzar un error
                            IF (STRLEN(pLscTransactionHeader."LSDX NCF") <> DXNCFSetup."Digitos e-CF") THEN BEGIN
                                //ERROR
                                ErrorBeep('Error: Comprobante NC Credito Fiscal no tiene el NCF Correcto');
                                EXIT(FALSE);
                            END;

                            IF (pLscTransactionHeader."LSDX RNC/Cedula" <> '') AND (pLscTransactionHeader."LSDX Razon Social" <> '') THEN BEGIN
                                IF ((STRLEN(pLscTransactionHeader."LSDX RNC/Cedula") <> 9) AND (STRLEN(pLscTransactionHeader."LSDX RNC/Cedula") <> 11)) THEN BEGIN
                                    //ERROR
                                    ErrorBeep('Error: Comprobante Cons. Final no tiene RNC correcto del Contribuyente');
                                    EXIT(FALSE);
                                END;

                                IF (pLscTransactionHeader."LSDX Razon Social" = '') THEN BEGIN
                                    //ERROR
                                    ErrorBeep('Error: Comprobante Cons. Final debe llevar Razon Social del Contribuyente');
                                    EXIT(FALSE);
                                END;
                            END

                            ELSE
                                IF (pLscTransactionHeader."LSDX RNC/Cedula" = '') AND (pLscTransactionHeader."LSDX Razon Social" = '') THEN BEGIN
                                    IF (pLscTransactionHeader."LSDX RNC/Cedula" <> '') THEN BEGIN
                                        //ERROR
                                        ErrorBeep('Error: Comprobante Cons. Final no debe tener RNC de contribuyente');
                                        EXIT(FALSE);
                                    END;

                                    IF (pLscTransactionHeader."LSDX Razon Social" <> '') THEN BEGIN
                                        //ERROR
                                        ErrorBeep('Error: Comprobante Cons. Final no debe llevar Razon Social del Contribuyente');
                                        EXIT(FALSE);
                                    END;

                                END;

                            // Se valida que no haya un NCF Afectado
                            IF (STRLEN(pLscTransactionHeader."LSDX NCF Afectado") <> DXNCFSetup."Digitos e-CF") THEN BEGIN
                                //ERROR
                                ErrorBeep('Error: Comprobante NC Cons. Final no tiene el NCF Afectado Correcto');
                                EXIT(FALSE);
                            END;
                        END;


                    pLscTransactionHeader."LSDX Tipo Doc. Fiscal"::"Reg. Especial":
                        begin
                            pLscTransactionHeader."LSEF e-NCF Type" := "EF eCFType"::"E44 Free Zone";
                            IF (STRLEN(pLscTransactionHeader."LSDX NCF") <> DXNCFSetup."Digitos e-CF") THEN BEGIN
                                //ERROR
                                ErrorBeep('Error: Comprobante Regimen Especial no tiene el NCF Correcto');
                                EXIT(FALSE);
                            END

                            ELSE
                                IF ((STRLEN(pLscTransactionHeader."LSDX RNC/Cedula") <> 9) AND (STRLEN(pLscTransactionHeader."LSDX RNC/Cedula") <> 11)) THEN BEGIN
                                    //ERROR
                                    ErrorBeep('Error: Comprobante Regimen Especial no tiene el RNC Correcto');
                                    EXIT(FALSE);
                                END

                                ELSE
                                    IF (pLscTransactionHeader."LSDX Razon Social" = '') THEN BEGIN
                                        //ERROR
                                        ErrorBeep('Error: Comprobante Reg. Especial debe tener la Razon Social del Contribuyente');
                                        EXIT(FALSE);
                                    END

                                    ELSE
                                        IF (pLscTransactionHeader."LSDX NCF Afectado" <> '') THEN BEGIN
                                            //ERROR
                                            ErrorBeep('Error: Comprobante Regimen Especial no lleva NCF Afectado');
                                            EXIT(FALSE);
                                        END;


                        end;
                    pLscTransactionHeader."LSDX Tipo Doc. Fiscal"::Governmental:
                        begin
                            pLscTransactionHeader."LSEF e-NCF Type" := "EF eCFType"::"E45 Government";
                            // Validacion length del NCF que sea 19 de lo contrario lanzar un error
                            IF (STRLEN(pLscTransactionHeader."LSDX NCF") <> DXNCFSetup."Digitos e-CF") THEN BEGIN
                                //ERROR
                                ErrorBeep('Error: Comprobante Gubernamental no tiene el NCF Correcto');
                                EXIT(FALSE);
                            END

                            // Validacion  del RNC del contribuyente, solo se valida el length
                            ELSE
                                IF ((STRLEN(pLscTransactionHeader."LSDX RNC/Cedula") <> 9) AND (STRLEN(pLscTransactionHeader."LSDX RNC/Cedula") <> 11)) THEN BEGIN
                                    //ERROR
                                    ErrorBeep('Error: Comprobante Gubernamental no tiene el RNC Correcto');
                                    EXIT(FALSE);
                                END

                                ELSE
                                    IF (pLscTransactionHeader."LSDX Razon Social" = '') THEN BEGIN
                                        //ERROR
                                        ErrorBeep('Error: Comprobante Gubernamental debe tener la Razon Social del Contribuyente');
                                        EXIT(FALSE);
                                    END

                                    ELSE
                                        IF (pLscTransactionHeader."LSDX NCF Afectado" <> '') THEN BEGIN
                                            //ERROR
                                            ErrorBeep('Error: Comprobante Gubernamental no lleva NCF Afectado');
                                            EXIT(FALSE);
                                        END;


                        end;
                end;
                IsHandled := true;
                exit(true);
            end else
                exit(false);
    end;

    procedure ErrorBeep(pMsg: Text[250])
    begin
        if LsdxPosSetup.Get() then
            if LsdxPosSetup."Use POS Localization" then begin
                LscPosOposUtility.Beeper();
                LscPosOposUtility.Beeper();

                if pMsg <> '' then
                    LscPosGui.PosMessage(pMsg);
            end;
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeValidateFiscalData(var LscTransactionHeader: Record "LSC Transaction Header"; var IsHandled: Boolean)
    begin

    end;

    procedure InitQRArguments(LSCTransactionHeader: Record "LSC Transaction Header")
    var
        initCompanyInformation: Record "Company Information";
        TempBlob: Codeunit "Temp Blob";
        Base64Convert: Codeunit "Base64 Convert";
        EFUtilityManagement: Codeunit "EF Utility Management";
        isOutStream: OutStream;
        PisOutStream: OutStream;
        isInStream: InStream;
        PisInStream: InStream;
        SigValue: Text;
        EncodedText: Text;
        RncComprador: Text[15];
        eNCF: Text[13];
        fechEmision: Date;
        MontoTotal: Decimal;
        fechaFirma: Text[20];
        securityCode: Text[6];
        Base64QRText: Text;

    begin
        initCompanyInformation.Get();
        LSCTransactionHeader.CalcFields("LSEF Signature Value", "LSEF Encoded Barcode");

        RncComprador := CopyStr(LSCTransactionHeader."LSDX RNC/Cedula", 1, 15);
        eNCF := CopyStr(LSCTransactionHeader."LSDX NCF", 1, 13);
        fechEmision := LSCTransactionHeader.Date;

        if LSCTransactionHeader."Trans. Currency" = '' then
            MontoTotal := Abs(LSCTransactionHeader."Gross Amount")
        else
            MontoTotal := abs(LSCTransactionHeader."Gross Amount" / 1); //TODO: VALIDAR COMO SE DETERMINA EL CURRENCY FACTOR EN EL POS.

        fechaFirma := LSCTransactionHeader."LSEF Stamped Date/Time";
        securityCode := LSCTransactionHeader."LSEF Security Code";


        if LSCTransactionHeader."LSEF Security Code" <> '' then
            SigValue := LSCTransactionHeader."LSEF Security Code"
        else
            if LSCTransactionHeader."LSEF Signature Value".HasValue() then begin
                LSCTransactionHeader."LSEF Signature Value".CreateInStream(isInStream);
                isInStream.Read(SigValue);
            end;

        if LSCTransactionHeader."LSEF Encoded Barcode".HasValue() then begin
            Clear(isInStream);
            LSCTransactionHeader."LSEF Encoded Barcode".CreateInStream(isInStream);
            isInStream.Read(Base64QRText);
        end else begin
            Base64QRText := EfUtilityManagement.getQRBase64(RncComprador, eNCF, fechEmision, MontoTotal, fechaFirma, securityCode);

            LSCTransactionHeader."LSEF Encoded Barcode".CreateOutStream(isOutStream);
            isOutStream.WriteText(Base64QRText);
            LSCTransactionHeader."LSEF Encoded Barcode".CreateInStream(isInStream);
            LSCTransactionHeader.Modify();
            LSCTransactionHeader.CalcFields("LSEF Encoded Barcode");
            if LSCTransactionHeader."LSEF Encoded Barcode".HasValue() then begin
                LSCTransactionHeader."LSEF Encoded Barcode".CreateInStream(PisInStream);
                PisInStream.Read(EncodedText);
                TempBlob.CreateOutStream(PisOutStream);
                if Text.StrLen(EncodedText) > 0 then begin
                    Base64Convert.FromBase64(EncodedText, PisOutStream);
                    TempBlob.CreateInStream(PisInStream);
                    Clear(LSCTransactionHeader.LSEfQRImage);
                    LSCTransactionHeader.LSEfQRImage.ImportStream(PisInStream, 'Barcode_Image_' + eNCF, 'image/jpeg');
                    LSCTransactionHeader.Modify();
                end;
            end;
        end;
    end;

}