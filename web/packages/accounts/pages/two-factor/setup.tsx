import log from "@/next/log";
import { ensure } from "@/utils/ensure";
import { enableTwoFactor, setupTwoFactor } from "@ente/accounts/api/user";
import VerifyTwoFactor, {
    type VerifyTwoFactorCallback,
} from "@ente/accounts/components/two-factor/VerifyForm";
import { TwoFactorSetup } from "@ente/accounts/components/two-factor/setup";
import type { TwoFactorSecret } from "@ente/accounts/types/user";
import { APP_HOMES, appNameToAppNameOld } from "@ente/shared/apps/constants";
import { VerticallyCentered } from "@ente/shared/components/Container";
import LinkButton from "@ente/shared/components/LinkButton";
import { encryptWithRecoveryKey } from "@ente/shared/crypto/helpers";
import { LS_KEYS, getData, setData } from "@ente/shared/storage/localStorage";
import { Box, CardContent, Typography } from "@mui/material";
import Card from "@mui/material/Card";
import { t } from "i18next";
import { useRouter } from "next/router";
import { useEffect, useState } from "react";
import type { PageProps } from "../../types/page";

export enum SetupMode {
    QR_CODE,
    MANUAL_CODE,
}

const Page: React.FC<PageProps> = ({ appContext }) => {
    const { appName } = appContext;

    const appNameOld = appNameToAppNameOld(appName);

    const [twoFactorSecret, setTwoFactorSecret] = useState<
        TwoFactorSecret | undefined
    >();

    const router = useRouter();

    useEffect(() => {
        if (twoFactorSecret) {
            return;
        }
        const main = async () => {
            try {
                const twoFactorSecret = await setupTwoFactor();
                setTwoFactorSecret(twoFactorSecret);
            } catch (e) {
                log.error("failed to get two factor setup code", e);
            }
        };
        main();
    }, []);

    const onSubmit: VerifyTwoFactorCallback = async (
        otp: string,
        markSuccessful,
    ) => {
        const recoveryEncryptedTwoFactorSecret = await encryptWithRecoveryKey(
            ensure(twoFactorSecret).secretCode,
        );
        await enableTwoFactor(otp, recoveryEncryptedTwoFactorSecret);
        await markSuccessful();
        setData(LS_KEYS.USER, {
            ...getData(LS_KEYS.USER),
            isTwoFactorEnabled: true,
        });
        // TODO: Refactor the type of APP_HOMES to not require the ??
        router.push(APP_HOMES.get(appNameOld) ?? "/");
    };

    return (
        <VerticallyCentered>
            <Card>
                <CardContent>
                    <VerticallyCentered sx={{ p: 3 }}>
                        <Box mb={4}>
                            <Typography variant="h2">
                                {t("TWO_FACTOR")}
                            </Typography>
                        </Box>
                        <TwoFactorSetup twoFactorSecret={twoFactorSecret} />
                        <VerifyTwoFactor
                            onSubmit={onSubmit}
                            buttonText={t("ENABLE")}
                        />
                        <LinkButton sx={{ mt: 2 }} onClick={router.back}>
                            {t("GO_BACK")}
                        </LinkButton>
                    </VerticallyCentered>
                </CardContent>
            </Card>
        </VerticallyCentered>
    );
};

export default Page;
