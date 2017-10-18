#!/bin/sh
patch --strip 1 <<EOF
diff --git a/trunk/proprietary/rt_wifi/rtpci/3.0.X.X/mt76x2/ap/ap_assoc.c b/trunk/proprietary/rt_wifi/rtpci/3.0.X.X/mt76x2/ap/ap_assoc.c
index e2efdc1..5a4a212 100644
--- a/trunk/proprietary/rt_wifi/rtpci/3.0.X.X/mt76x2/ap/ap_assoc.c
+++ b/trunk/proprietary/rt_wifi/rtpci/3.0.X.X/mt76x2/ap/ap_assoc.c
@@ -1283,11 +1283,7 @@ SendAssocResponse:
 			pFtIe = (PFT_FTIE)(ftie_ptr + 2);
 			NdisMoveMemory(pFtIe->MIC, ft_mic, FT_MIC_LEN);
 
-			/* Install pairwise key */
-			WPAInstallPairwiseKey(pAd, pEntry->apidx, pEntry, TRUE);
-
-			/* Update status and set Port as Secured */
-			pEntry->WpaState = AS_PTKINITDONE;
+			/* set Port as Secured */
 			pEntry->PrivacyFilter = Ndis802_11PrivFilterAcceptAll;
 		    pEntry->PortSecured = WPA_802_1X_PORT_SECURED;
 		}
diff --git a/trunk/proprietary/rt_wifi/rtpci/3.0.X.X/mt76x2/ap/ap_auth.c b/trunk/proprietary/rt_wifi/rtpci/3.0.X.X/mt76x2/ap/ap_auth.c
index da0263d..0fb69db 100644
--- a/trunk/proprietary/rt_wifi/rtpci/3.0.X.X/mt76x2/ap/ap_auth.c
+++ b/trunk/proprietary/rt_wifi/rtpci/3.0.X.X/mt76x2/ap/ap_auth.c
@@ -537,8 +537,15 @@ SendAuth:
     						&pFtInfoBuf->MdIeInfo, &pFtInfoBuf->FtIeInfo, NULL,
     						pFtInfoBuf->RSN_IE, pFtInfoBuf->RSNIE_Len);
 
-                os_free_mem(NULL, pFtInfoBuf);
-            }
+				os_free_mem(NULL, pFtInfoBuf);
+				if (result == MLME_SUCCESS) {
+					/* Install pairwise key */
+					WPAInstallPairwiseKey(pAd, pEntry->apidx, pEntry, TRUE);
+					/* Update status */
+					pEntry->WpaState = AS_PTKINITDONE;
+					pEntry->GTKState = REKEY_ESTABLISHED;
+				}
+			}
 		}
 		return;
 	}
diff --git a/trunk/proprietary/rt_wifi/rtpci/3.0.X.X/mt76x2/common/cmm_wpa.c b/trunk/proprietary/rt_wifi/rtpci/3.0.X.X/mt76x2/common/cmm_wpa.c
index 01922f2..03a7527 100644
--- a/trunk/proprietary/rt_wifi/rtpci/3.0.X.X/mt76x2/common/cmm_wpa.c
+++ b/trunk/proprietary/rt_wifi/rtpci/3.0.X.X/mt76x2/common/cmm_wpa.c
@@ -1225,6 +1225,9 @@ VOID PeerPairMsg1Action(
 		
 	/* Generate random SNonce*/
 	GenRandom(pAd, (UCHAR *)pCurrentAddr, pEntry->SNonce);
+	pEntry->AllowInsPTK = TRUE;
+	pEntry->LastGroupKeyId = 0;
+	NdisZeroMemory(pEntry->LastGTK, 32);
 
 #ifdef DOT11R_FT_SUPPORT	
 	if (IS_FT_RSN_STA(pEntry))
@@ -1877,9 +1880,16 @@ VOID PeerPairMsg3Action(
 #ifdef CONFIG_AP_SUPPORT
 	IF_DEV_CONFIG_OPMODE_ON_AP(pAd)
 	{
-#ifdef APCLI_SUPPORT	
-		if (IS_ENTRY_APCLI(pEntry))	
-		 	APCliInstallPairwiseKey(pAd, pEntry);
+#ifdef APCLI_SUPPORT
+		if (IS_ENTRY_APCLI(pEntry)) {
+			if(pEntry->AllowInsPTK == TRUE) {
+				APCliInstallPairwiseKey(pAd, pEntry);
+				pEntry->AllowInsPTK = FALSE;
+			} else {
+				DBGPRINT(RT_DEBUG_ERROR, ("!!!%s : the M3 reinstall attack, skip install key\n",
+						__func__));
+			}
+		}
 #endif /* APCLI_SUPPORT */
 	}
 #endif /* CONFIG_AP_SUPPORT */
@@ -4639,10 +4649,19 @@ BOOLEAN RTMPParseEapolKeyData(
 #ifdef APCLI_SUPPORT		
 		if (IS_ENTRY_APCLI(pEntry))
 		{
-			/* Set Group key material, TxMic and RxMic for AP-Client*/
-			if (!APCliInstallSharedKey(pAd, GTK, GTKLEN, DefaultIdx, pEntry))
-			{		
-				return FALSE;
+			/* Prevent the GTK reinstall key attack */
+			if (pEntry->LastGroupKeyId != DefaultIdx ||
+				!NdisEqualMemory(pEntry->LastGTK, GTK, MAX_LEN_GTK)) {
+				/* Set Group key material, TxMic and RxMic for AP-Client*/
+				if (!APCliInstallSharedKey(pAd, GTK, GTKLEN, DefaultIdx, pEntry))
+				{
+					return FALSE;
+				}
+				pEntry->LastGroupKeyId = DefaultIdx;
+				NdisMoveMemory(pEntry->LastGTK, GTK, MAX_LEN_GTK);
+			} else {
+				DBGPRINT(RT_DEBUG_ERROR, ("!!!%s : the Group reinstall attack, skip install key\n",
+						__func__));
 			}
 		}
 #endif /* APCLI_SUPPORT */
diff --git a/trunk/proprietary/rt_wifi/rtpci/3.0.X.X/mt76x2/include/rtmp.h b/trunk/proprietary/rt_wifi/rtpci/3.0.X.X/mt76x2/include/rtmp.h
index 5ce09e1..47b4d43 100644
--- a/trunk/proprietary/rt_wifi/rtpci/3.0.X.X/mt76x2/include/rtmp.h
+++ b/trunk/proprietary/rt_wifi/rtpci/3.0.X.X/mt76x2/include/rtmp.h
@@ -3021,6 +3021,9 @@ typedef struct _MAC_TABLE_ENTRY {
 	UCHAR R_Counter[LEN_KEY_DESC_REPLAY];
 	UCHAR PTK[64];
 	UCHAR ReTryCounter;
+	BOOLEAN AllowInsPTK;
+	UCHAR LastGroupKeyId;
+	UCHAR LastGTK[MAX_LEN_GTK];	
 	RALINK_TIMER_STRUCT RetryTimer;
 	NDIS_802_11_AUTHENTICATION_MODE AuthMode;	/* This should match to whatever microsoft defined */
 	NDIS_802_11_WEP_STATUS WepStatus;
diff --git a/trunk/proprietary/rt_wifi/rtpci/4.1.X.X/mt76x3/ap/ap_assoc.c b/trunk/proprietary/rt_wifi/rtpci/4.1.X.X/mt76x3/ap/ap_assoc.c
index 1764a9c..4ddac19 100644
--- a/trunk/proprietary/rt_wifi/rtpci/4.1.X.X/mt76x3/ap/ap_assoc.c
+++ b/trunk/proprietary/rt_wifi/rtpci/4.1.X.X/mt76x3/ap/ap_assoc.c
@@ -1664,11 +1664,7 @@ SendAssocResponse:
 			pFtIe = (PFT_FTIE)(ftie_ptr + 2);
 			NdisMoveMemory(pFtIe->MIC, ft_mic, FT_MIC_LEN);
 
-			/* Install pairwise key */
-			WPAInstallPairwiseKey(pAd, pEntry->func_tb_idx, pEntry, TRUE);
-
-			/* Update status and set Port as Secured */
-			pEntry->WpaState = AS_PTKINITDONE;
+			/* set Port as Secured */
 			pEntry->PrivacyFilter = Ndis802_11PrivFilterAcceptAll;
 			tr_entry->PortSecured = WPA_802_1X_PORT_SECURED;
 		}
diff --git a/trunk/proprietary/rt_wifi/rtpci/4.1.X.X/mt76x3/ap/ap_auth.c b/trunk/proprietary/rt_wifi/rtpci/4.1.X.X/mt76x3/ap/ap_auth.c
index 16a9057..07b0588 100644
--- a/trunk/proprietary/rt_wifi/rtpci/4.1.X.X/mt76x3/ap/ap_auth.c
+++ b/trunk/proprietary/rt_wifi/rtpci/4.1.X.X/mt76x3/ap/ap_auth.c
@@ -604,6 +604,13 @@ SendAuth:
 							pFtInfoBuf->RSN_IE, pFtInfoBuf->RSNIE_Len);
 
 				os_free_mem(NULL, pFtInfoBuf);
+				if (result == MLME_SUCCESS) {
+					/* Install pairwise key */
+					WPAInstallPairwiseKey(pAd, pEntry->func_tb_idx, pEntry, TRUE);
+					/* Update status */
+					pEntry->WpaState = AS_PTKINITDONE;
+					pEntry->GTKState = REKEY_ESTABLISHED;
+				}
 			}
 		}
 		return;
diff --git a/trunk/proprietary/rt_wifi/rtpci/4.1.X.X/mt76x3/common/cmm_wpa.c b/trunk/proprietary/rt_wifi/rtpci/4.1.X.X/mt76x3/common/cmm_wpa.c
index 0248613..48b4719 100644
--- a/trunk/proprietary/rt_wifi/rtpci/4.1.X.X/mt76x3/common/cmm_wpa.c
+++ b/trunk/proprietary/rt_wifi/rtpci/4.1.X.X/mt76x3/common/cmm_wpa.c
@@ -1109,6 +1109,9 @@ VOID PeerPairMsg1Action(
 
 	/* Generate random SNonce*/
 	GenRandom(pAd, (UCHAR *)pCurrentAddr, pEntry->SNonce);
+	pEntry->AllowInsPTK = TRUE;
+	pEntry->LastGroupKeyId = 0;
+	NdisZeroMemory(pEntry->LastGTK, 32);
 
 #ifdef DOT11R_FT_SUPPORT
 	if (IS_FT_RSN_STA(pEntry))
@@ -1734,8 +1737,15 @@ VOID PeerPairMsg3Action(
 	IF_DEV_CONFIG_OPMODE_ON_AP(pAd)
 	{
 #ifdef APCLI_SUPPORT
-		if (IS_ENTRY_APCLI(pEntry))
-		 	APCliInstallPairwiseKey(pAd, pEntry);
+		if (IS_ENTRY_APCLI(pEntry)) {
+			if(pEntry->AllowInsPTK == TRUE) {
+				APCliInstallPairwiseKey(pAd, pEntry);
+				pEntry->AllowInsPTK = FALSE;
+			} else {
+				DBGPRINT(RT_DEBUG_ERROR, ("!!!%s : the M3 reinstall attack, skip install key\n",
+						__func__));
+			}
+		}
 #endif /* APCLI_SUPPORT */
 	}
 #endif /* CONFIG_AP_SUPPORT */
@@ -4182,10 +4192,19 @@ BOOLEAN RTMPParseEapolKeyData(
 #ifdef APCLI_SUPPORT
 		if ((pAd->chipCap.hif_type == HIF_RLT || pAd->chipCap.hif_type == HIF_RTMP) && IS_ENTRY_APCLI(pEntry))
 		{
-			/* Set Group key material, TxMic and RxMic for AP-Client*/
-			if (!APCliInstallSharedKey(pAd, GTK, GTKLEN, DefaultIdx, pEntry))
-			{
-				return FALSE;
+			/* Prevent the GTK reinstall key attack */
+			if (pEntry->LastGroupKeyId != DefaultIdx ||
+					!NdisEqualMemory(pEntry->LastGTK, GTK, MAX_LEN_GTK)) {
+				/* Set Group key material, TxMic and RxMic for AP-Client*/
+				if (!APCliInstallSharedKey(pAd, GTK, GTKLEN, DefaultIdx, pEntry))
+				{
+					return FALSE;
+				}
+				pEntry->LastGroupKeyId = DefaultIdx;
+				NdisMoveMemory(pEntry->LastGTK, GTK, MAX_LEN_GTK);
+			} else {
+				DBGPRINT(RT_DEBUG_ERROR, ("!!!%s : the Group reinstall attack, skip install key\n",
+						__func__));
 			}
 		}
 #ifdef MT_MAC
diff --git a/trunk/proprietary/rt_wifi/rtpci/4.1.X.X/mt76x3/include/rtmp.h b/trunk/proprietary/rt_wifi/rtpci/4.1.X.X/mt76x3/include/rtmp.h
index da77ddb..a34f25c 100644
--- a/trunk/proprietary/rt_wifi/rtpci/4.1.X.X/mt76x3/include/rtmp.h
+++ b/trunk/proprietary/rt_wifi/rtpci/4.1.X.X/mt76x3/include/rtmp.h
@@ -2487,6 +2487,9 @@ typedef struct _MAC_TABLE_ENTRY {
 	UCHAR R_Counter[LEN_KEY_DESC_REPLAY];
 	UCHAR PTK[64];
 	UCHAR ReTryCounter;
+	BOOLEAN AllowInsPTK;
+	UCHAR LastGroupKeyId;
+	UCHAR LastGTK[MAX_LEN_GTK];
 	RALINK_TIMER_STRUCT RetryTimer;
 	NDIS_802_11_AUTHENTICATION_MODE AuthMode;	/* This should match to whatever microsoft defined */
 	NDIS_802_11_WEP_STATUS WepStatus;
diff --git a/trunk/proprietary/rt_wifi/rtsoc/2.7.X.X/rt2860v2/common/cmm_wpa.c b/trunk/proprietary/rt_wifi/rtsoc/2.7.X.X/rt2860v2/common/cmm_wpa.c
index 553af2b..d4be0f3 100644
--- a/trunk/proprietary/rt_wifi/rtsoc/2.7.X.X/rt2860v2/common/cmm_wpa.c
+++ b/trunk/proprietary/rt_wifi/rtsoc/2.7.X.X/rt2860v2/common/cmm_wpa.c
@@ -1123,6 +1123,9 @@ VOID PeerPairMsg1Action(
 		
 	/* Generate random SNonce*/
 	GenRandom(pAd, (UCHAR *)pCurrentAddr, pEntry->SNonce);
+	pEntry->AllowInsPTK = TRUE;
+	pEntry->LastGroupKeyId = 0;
+	NdisZeroMemory(pEntry->LastGTK, 32);
 
 	{
 	    /* Calculate PTK(ANonce, SNonce)*/
@@ -1521,9 +1524,16 @@ VOID PeerPairMsg3Action(
 #ifdef CONFIG_AP_SUPPORT
 	IF_DEV_CONFIG_OPMODE_ON_AP(pAd)
 	{
-#ifdef APCLI_SUPPORT	
-		if (IS_ENTRY_APCLI(pEntry))	
-		 	APCliInstallPairwiseKey(pAd, pEntry);
+#ifdef APCLI_SUPPORT
+		if (IS_ENTRY_APCLI(pEntry)) {
+			if(pEntry->AllowInsPTK == TRUE) {
+				APCliInstallPairwiseKey(pAd, pEntry);
+				pEntry->AllowInsPTK = FALSE;
+			} else {
+				DBGPRINT(RT_DEBUG_ERROR, ("!!!%s : the M3 reinstall attack, skip install key\n",
+						__func__));
+			}
+		}
 #endif /* APCLI_SUPPORT */
 	}
 #endif /* CONFIG_AP_SUPPORT */
@@ -3816,11 +3826,20 @@ BOOLEAN RTMPParseEapolKeyData(
 #ifdef APCLI_SUPPORT		
 		if (IS_ENTRY_APCLI(pEntry))
 		{
-			/* Set Group key material, TxMic and RxMic for AP-Client*/
-			if (!APCliInstallSharedKey(pAd, GTK, GTKLEN, DefaultIdx, pEntry))
-			{		
-				return FALSE;
-			}
+			/* Prevent the GTK reinstall key attack */
+			if (pEntry->LastGroupKeyId != DefaultIdx ||
+				!NdisEqualMemory(pEntry->LastGTK, GTK, MAX_LEN_GTK)) {
+				/* Set Group key material, TxMic and RxMic for AP-Client*/
+				if (!APCliInstallSharedKey(pAd, GTK, GTKLEN, DefaultIdx, pEntry))
+				{
+					return FALSE;
+				}
+				pEntry->LastGroupKeyId = DefaultIdx;
+				NdisMoveMemory(pEntry->LastGTK, GTK, MAX_LEN_GTK);
+			} else {
+				DBGPRINT(RT_DEBUG_ERROR, ("!!!%s : the Group reinstall attack, skip install key\n",
+						__func__));
+ 			}
 		}
 #endif /* APCLI_SUPPORT */
 #endif /* CONFIG_AP_SUPPORT */
diff --git a/trunk/proprietary/rt_wifi/rtsoc/2.7.X.X/rt2860v2/include/rtmp.h b/trunk/proprietary/rt_wifi/rtsoc/2.7.X.X/rt2860v2/include/rtmp.h
index efeee2d..40d23df 100644
--- a/trunk/proprietary/rt_wifi/rtsoc/2.7.X.X/rt2860v2/include/rtmp.h
+++ b/trunk/proprietary/rt_wifi/rtsoc/2.7.X.X/rt2860v2/include/rtmp.h
@@ -2414,6 +2414,9 @@ typedef struct _MAC_TABLE_ENTRY {
 	UCHAR R_Counter[LEN_KEY_DESC_REPLAY];
 	UCHAR PTK[64];
 	UCHAR ReTryCounter;
+	BOOLEAN AllowInsPTK;
+	UCHAR LastGroupKeyId;
+	UCHAR LastGTK[MAX_LEN_GTK];
 	RALINK_TIMER_STRUCT RetryTimer;
 	RALINK_TIMER_STRUCT Start2WayGroupHSTimer;
 #ifdef TXBF_SUPPORT
diff --git a/trunk/proprietary/rt_wifi/rtsoc/4.1.X.X/mt7628/embedded/ap/ap_assoc.c b/trunk/proprietary/rt_wifi/rtsoc/4.1.X.X/mt7628/embedded/ap/ap_assoc.c
index 0dd1c10..683569c 100644
--- a/trunk/proprietary/rt_wifi/rtsoc/4.1.X.X/mt7628/embedded/ap/ap_assoc.c
+++ b/trunk/proprietary/rt_wifi/rtsoc/4.1.X.X/mt7628/embedded/ap/ap_assoc.c
@@ -1488,11 +1488,7 @@ SendAssocResponse:
 			pFtIe = (PFT_FTIE)(ftie_ptr + 2);
 			NdisMoveMemory(pFtIe->MIC, ft_mic, FT_MIC_LEN);
 
-			/* Install pairwise key */
-			WPAInstallPairwiseKey(pAd, pEntry->func_tb_idx, pEntry, TRUE);
-
-			/* Update status and set Port as Secured */
-			pEntry->WpaState = AS_PTKINITDONE;
+			/* set Port as Secured */
 			pEntry->PrivacyFilter = Ndis802_11PrivFilterAcceptAll;
 			tr_entry->PortSecured = WPA_802_1X_PORT_SECURED;
 		}
diff --git a/trunk/proprietary/rt_wifi/rtsoc/4.1.X.X/mt7628/embedded/ap/ap_auth.c b/trunk/proprietary/rt_wifi/rtsoc/4.1.X.X/mt7628/embedded/ap/ap_auth.c
index bd584ec..3a3f039 100644
--- a/trunk/proprietary/rt_wifi/rtsoc/4.1.X.X/mt7628/embedded/ap/ap_auth.c
+++ b/trunk/proprietary/rt_wifi/rtsoc/4.1.X.X/mt7628/embedded/ap/ap_auth.c
@@ -566,6 +566,13 @@ SendAuth:
 							pFtInfoBuf->RSN_IE, pFtInfoBuf->RSNIE_Len);
 
 				os_free_mem(NULL, pFtInfoBuf);
+				if (result == MLME_SUCCESS) {
+					/* Install pairwise key */
+					WPAInstallPairwiseKey(pAd, pEntry->func_tb_idx, pEntry, TRUE);
+					/* Update status */
+					pEntry->WpaState = AS_PTKINITDONE;
+					pEntry->GTKState = REKEY_ESTABLISHED;
+				}				
 			}
 		}
 		return;
diff --git a/trunk/proprietary/rt_wifi/rtsoc/4.1.X.X/mt7628/embedded/common/cmm_wpa.c b/trunk/proprietary/rt_wifi/rtsoc/4.1.X.X/mt7628/embedded/common/cmm_wpa.c
index 3a819b3..0232213 100644
--- a/trunk/proprietary/rt_wifi/rtsoc/4.1.X.X/mt7628/embedded/common/cmm_wpa.c
+++ b/trunk/proprietary/rt_wifi/rtsoc/4.1.X.X/mt7628/embedded/common/cmm_wpa.c
@@ -1127,6 +1127,9 @@ VOID PeerPairMsg1Action(
 
 	/* Generate random SNonce*/
 	GenRandom(pAd, (UCHAR *)pCurrentAddr, pEntry->SNonce);
+	pEntry->AllowInsPTK = TRUE;
+	pEntry->LastGroupKeyId = 0;
+	NdisZeroMemory(pEntry->LastGTK, 32);
 
 #ifdef DOT11R_FT_SUPPORT
 	if (IS_FT_RSN_STA(pEntry))
@@ -1800,8 +1803,15 @@ VOID PeerPairMsg3Action(
 	IF_DEV_CONFIG_OPMODE_ON_AP(pAd)
 	{
 #ifdef APCLI_SUPPORT
-		if (IS_ENTRY_APCLI(pEntry))
-		 	APCliInstallPairwiseKey(pAd, pEntry);
+		if (IS_ENTRY_APCLI(pEntry)) {
+			if(pEntry->AllowInsPTK == TRUE) {
+				APCliInstallPairwiseKey(pAd, pEntry);
+				pEntry->AllowInsPTK = FALSE;
+			} else {
+				MTWF_LOG(DBG_CAT_ALL, DBG_SUBCAT_ALL, DBG_LVL_ERROR,
+						("!!!%s : the M3 reinstall attack, skip install key\n", __func__));
+			}
+		}
 #endif /* APCLI_SUPPORT */
 	}
 #endif /* CONFIG_AP_SUPPORT */
@@ -4362,10 +4372,19 @@ BOOLEAN RTMPParseEapolKeyData(
 #ifdef APCLI_SUPPORT
 		if ((pAd->chipCap.hif_type == HIF_RLT || pAd->chipCap.hif_type == HIF_RTMP) && IS_ENTRY_APCLI(pEntry))
 		{
-			/* Set Group key material, TxMic and RxMic for AP-Client*/
-			if (!APCliInstallSharedKey(pAd, GTK, GTKLEN, DefaultIdx, pEntry))
-			{
-				return FALSE;
+			/* Prevent the GTK reinstall key attack */
+			if (pEntry->LastGroupKeyId != DefaultIdx ||
+					!NdisEqualMemory(pEntry->LastGTK, GTK, MAX_LEN_GTK)) {
+				/* Set Group key material, TxMic and RxMic for AP-Client*/
+				if (!APCliInstallSharedKey(pAd, GTK, GTKLEN, DefaultIdx, pEntry))
+				{
+					return FALSE;
+				}
+				pEntry->LastGroupKeyId = DefaultIdx;
+				NdisMoveMemory(pEntry->LastGTK, GTK, MAX_LEN_GTK);
+			} else {
+				MTWF_LOG(DBG_CAT_ALL, DBG_SUBCAT_ALL, DBG_LVL_ERROR,
+						("!!!%s : the Group reinstall attack, skip install key\n", __func__));						
 			}
 		}
 #ifdef MT_MAC
diff --git a/trunk/proprietary/rt_wifi/rtsoc/4.1.X.X/mt7628/embedded/include/rtmp.h b/trunk/proprietary/rt_wifi/rtsoc/4.1.X.X/mt7628/embedded/include/rtmp.h
index 6ff1034..7625e9d 100644
--- a/trunk/proprietary/rt_wifi/rtsoc/4.1.X.X/mt7628/embedded/include/rtmp.h
+++ b/trunk/proprietary/rt_wifi/rtsoc/4.1.X.X/mt7628/embedded/include/rtmp.h
@@ -2973,6 +2973,9 @@ typedef struct _MAC_TABLE_ENTRY {
 	UCHAR R_Counter[LEN_KEY_DESC_REPLAY];
 	UCHAR PTK[64];
 	UCHAR ReTryCounter;
+	BOOLEAN AllowInsPTK;
+	UCHAR LastGroupKeyId;
+	UCHAR LastGTK[MAX_LEN_GTK];
 	RALINK_TIMER_STRUCT RetryTimer;
 	NDIS_802_11_AUTHENTICATION_MODE AuthMode;	/* This should match to whatever microsoft defined */
 	NDIS_802_11_WEP_STATUS WepStatus;
EOF
