SCRIPTS=veritawall-bootstrap.sh
MAN=	veritawall-bootstrap.8

LOCALBASE?=${DESTDIR}/usr/local
PREFIX?=${LOCALBASE}

BINDIR=	${PREFIX}/sbin
MANDIR=	${PREFIX}/man/man

CLEANFILES=	${SCRIPTS}

${SCRIPTS}: ${SCRIPTS}.in
	sed -e 's|%%RELEASE%%|${BOOTSTRAP_RELEASE}|g' ${.ALLSRC} > ${.TARGET}

.include <bsd.prog.mk>
