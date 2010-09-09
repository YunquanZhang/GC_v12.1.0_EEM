!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !MODULE: merra_a3_mod
!
! !DESCRIPTION: Module MERRA\_A3\_MOD contains subroutines for reading the 
!  3-hour time averaged (aka "A3") fields from the MERRA data archive.
!\\
!\\
! !INTERFACE: 
!
      MODULE MERRA_A3_MOD
!
! !USES:
!
      IMPLICIT NONE
      PRIVATE
!
! !PUBLIC MEMBER FUNCTIONS:
! 
      PUBLIC  :: GET_MERRA_A3_FIELDS
      PUBLIC  :: OPEN_MERRA_A3_FIELDS
!
! !PRIVATE MEMBER FUNCTIONS:
! 
      PRIVATE :: A3_CHECK
      PRIVATE :: DO_OPEN_A3
      PRIVATE :: READ_A3
!
! !REMARKS:
!  Don't bother with the file unzipping anymore.
!
! !REVISION HISTORY:
!  19 Aug 2010 - R. Yantosca - Initial version, based on i6_read_mod.f
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !PRIVATE TYPES:
!
      INTEGER :: N_A3_FIELDS    ! # of fields in the file

      CONTAINS
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: do_open_a3
!
! !DESCRIPTION: unction DO\_OPEN\_A3 returns TRUE if is time to open the A3 
!  met field file or FALSE otherwise.  This prevents us from opening a file 
!  which has already been opened. 
!\\
!\\
! !INTERFACE:
!
      FUNCTION DO_OPEN_A3( NYMD, NHMS ) RESULT( DO_OPEN )
!
! !INPUT PARAMETERS: 
!
      INTEGER, INTENT(IN) :: NYMD      ! YYYYMMDD and hhmmss to be tested
      INTEGER, INTENT(IN) :: NHMS      !  to see if it's time to open A3 file
!
! !RETURN VALUE:
!
      LOGICAL             :: DO_OPEN   ! = T if it is time to open the file
! 
! !REVISION HISTORY: 
!  20 Aug 2010 - R. Yantosca - Initial version, based on a3_read_mod.f
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES
!
      LOGICAL, SAVE :: FIRST    = .TRUE.
      INTEGER, SAVE :: LASTNYMD = -1
      INTEGER, SAVE :: LASTNHMS = -1
      
      !=================================================================
      ! DO_OPEN_A3 begins here!
      !=================================================================

      ! Initialize
      DO_OPEN = .FALSE.
         
      ! Return if we have already opened the file
      IF ( NYMD == LASTNYMD .and. NHMS == LASTNHMS ) THEN
         DO_OPEN = .FALSE. 
         GOTO 999
      ENDIF

      ! Open file if it's 01:30 GMT or first call (all GEOS data)
      IF ( NHMS == 013000 .or. FIRST ) THEN
         DO_OPEN = .TRUE. 
         GOTO 999
      ENDIF

      !=================================================================
      ! Reset quantities for next call
      !=================================================================
 999  CONTINUE
      LASTNYMD = NYMD
      LASTNHMS = NHMS
      FIRST    = .FALSE.
      
      END FUNCTION DO_OPEN_A3
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: open_merra_a3_fields
!
! !DESCRIPTION: Subroutine OPEN\_MERRA\_A3\_FIELDS opens the A3 met fields 
!  file for date NYMD and time NHMS. 
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE OPEN_MERRA_A3_FIELDS( NYMD, NHMS )
!
! !USES:
!
      USE BPCH2_MOD,     ONLY : GET_RES_EXT
      USE DIRECTORY_MOD, ONLY : DATA_DIR
      USE DIRECTORY_MOD, ONLY : MERRA_DIR
      USE ERROR_MOD,     ONLY : ERROR_STOP
      USE FILE_MOD,      ONLY : FILE_EXISTS
      USE FILE_MOD,      ONLY : IU_A3
      USE FILE_MOD,      ONLY : IOERROR
      USE TIME_MOD,      ONLY : EXPAND_DATE

#     include "CMN_SIZE"      ! Size parameters
!
! !INPUT PARAMETERS: 
!
      INTEGER, INTENT(IN) :: NYMD   ! YYYYMMDD and
      INTEGER, INTENT(IN) :: NHMS   !  hhmmss to test for A3 file open
! 
! !REVISION HISTORY: 
!  20 Aug 2010 - R. Yantosca - Initial version, based on a6_read_mod.f
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES
!
      LOGICAL, SAVE      :: FIRST = .TRUE.
      LOGICAL            :: IT_EXISTS
      INTEGER            :: IOS, IUNIT
      CHARACTER(LEN=8)   :: IDENT
      CHARACTER(LEN=255) :: A3_FILE
      CHARACTER(LEN=255) :: GEOS_DIR
      CHARACTER(LEN=255) :: PATH

      !=================================================================
      ! OPEN_MERRA_A3_FIELDS begins here!
      !=================================================================

      ! Check if it's time to open file
      IF ( DO_OPEN_A3( NYMD, NHMS ) ) THEN

         !---------------------------
         ! Initialization
         !---------------------------

         ! Strings for directory & filename
         GEOS_DIR = TRIM( MERRA_DIR )
         A3_FILE  = 'YYYYMMDD.a3.' // GET_RES_EXT()

         ! Replace date tokens
         CALL EXPAND_DATE( GEOS_DIR, NYMD, NHMS )
         CALL EXPAND_DATE( A3_FILE,  NYMD, NHMS )

         ! Full file path
         PATH = TRIM( DATA_DIR ) // 
     &          TRIM( GEOS_DIR ) // TRIM( A3_FILE )

         ! Close previously opened A-3 file
         CLOSE( IU_A3 )

         ! Make sure the file unit is valid before we open the file
         IF ( .not. FILE_EXISTS( IU_A3 ) ) THEN
            CALL ERROR_STOP( 'Could not find file!', 
     &                       'OPEN_MERRA_A3_FIELDS (merra_a3_mod.f)' )
         ENDIF

         !---------------------------
         ! Open the A3 file
         !---------------------------

         ! Open the file
         OPEN( UNIT   = IU_A3,         FILE   = TRIM( PATH ),
     &         STATUS = 'OLD',         ACCESS = 'SEQUENTIAL',  
     &         FORM   = 'UNFORMATTED', IOSTAT = IOS )
               
         IF ( IOS /= 0 ) THEN
            CALL IOERROR( IOS, IU_A3, 'open_merra_a3_fields:1' )
         ENDIF

         ! Echo info
         WRITE( 6, 100 ) TRIM( PATH )
 100     FORMAT( '     - Opening: ', a ) 

         !---------------------------
         ! Get # of fields in file
         !---------------------------

         ! Read the IDENT string
         READ( IU_A3, IOSTAT=IOS ) IDENT

         IF ( IOS /= 0 ) THEN
            CALL IOERROR( IOS, IU_A3, 'open_merra_a3_fields:2' )
         ENDIF

         ! The last 2 digits of the ident string
         ! is the # of fields contained in the file
         READ( IDENT(7:8), '(i2.2)' ) N_A3_FIELDS

      ENDIF

      END SUBROUTINE OPEN_MERRA_A3_FIELDS
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: get_merra_a3_fields
!
! !DESCRIPTION: Subroutine GET\_MERRA\_A3\_FIELDS is a wrapper for routine 
!  READ\_A3.
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE GET_MERRA_A3_FIELDS( NYMD, NHMS )
!
! !USES:
!
      USE DAO_MOD, ONLY : CLDF,    CLDTOPS,  CMFMC,    DQRCU
      USE DAO_MOD, ONLY : DQRLSAN, DQIDTMST, DQLDTMST, DQVDTMST
      USE DAO_MOD, ONLY : DTRAIN,  MOISTQ,   OPTDEP,   PFICU
      USE DAO_MOD, ONLY : PFILSAN, PFLCU,    PFLLSAN,  QI
      USE DAO_MOD, ONLY : QL,      SPHU,     REEVAPCN, REEVAPLS
      USE DAO_MOD, ONLY : T,       TAUCLI,   TAUCLW,   UWND
      USE DAO_MOD, ONLY : VWND

#     include "CMN_SIZE"            ! Size parameters
!
! !INPUT PARAMETERS: 
!
      INTEGER, INTENT(IN) :: NYMD   ! YYYYMMDD and
      INTEGER, INTENT(IN) :: NHMS   !  hhmmss of desired data fields
! 
! !REVISION HISTORY: 
!  20 Aug 2010 - R. Yantosca - Initial version, based on a3_read_mod.f
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES
!
      INTEGER, SAVE :: LASTNYMD = -1   ! Previous date read
      INTEGER, SAVE :: LASTNHMS = -1   ! Previous time read

      !=================================================================
      ! Initialization
      !=================================================================

      ! Skip over previously-read A-6 fields
      IF ( NYMD == LASTNYMD .and. NHMS == LASTNHMS ) THEN
         WRITE( 6, 100 ) NYMD, NHMS
 100     FORMAT( '     - MERRA A3 met fields for NYMD, NHMS = ', 
     &           i8.8, 1x, i6.6, ' have been read already' ) 
         RETURN
      ENDIF

      !=================================================================      
      ! Read data from disk
      !=================================================================
      CALL READ_A3( NYMD     = NYMD,          
     &              NHMS     = NHMS,       
     &              CLOUD    = CLDF,          
     &              CLDTOPS  = CLDTOPS, 
     &              CMFMC    = CMFMC, 
     &              DQRCU    = DQRCU, 
     &              DQRLSAN  = DQRLSAN,       
     &              DQIDTMST = DQIDTMST, 
     &              DQLDTMST = DQLDTMST,  
     &              DQVDTMST = DQVDTMST,  
     &              DTRAIN   = DTRAIN,     
     &              MOISTQ   = MOISTQ,     
     &              OPTDEPTH = OPTDEP, 
     &              PFICU    = PFICU,             
     &              PFILSAN  = PFILSAN,             
     &              PFLCU    = PFLCU,
     &              PFLLSAN  = PFLLSAN,
     &              QI       = QI,             
     &              QL       = QL,             
     &              QV       = SPHU,
     &              REEVAPCN = REEVAPCN,
     &              REEVAPLS = REEVAPLS,
     &              T        = T,               
     &              TAUCLI   = TAUCLI,     
     &              TAUCLW   = TAUCLW,     
     &              U        = UWND,            
     &              V        = VWND      )   

      ! Save NYMD and NHMS for next call
      LASTNYMD = NYMD
      LASTNHMS = NHMS

      END SUBROUTINE GET_MERRA_A3_FIELDS
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: read_a3 
!
! !DESCRIPTION: Subroutine READ\_A3 reads the MERRA 3-hour time-averaged
!  (aka "A3") met fields from disk.
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE READ_A3( NYMD,     NHMS,
     &                    CLOUD,    CLDTOPS,  CMFMC,    DQRCU,    
     &                    DQRLSAN,  DQIDTMST, DQLDTMST, DQVDTMST, 
     &                    DTRAIN,   MOISTQ,   OPTDEPTH, PFICU,    
     &                    PFILSAN,  PFLCU,    PFLLSAN,  QI,       
     &                    QL,       QV,       REEVAPCN, REEVAPLS, 
     &                    T,        TAUCLI,   TAUCLW,   U,        
     &                    V                                       )
!
! !USES:
!
      USE DIAG_MOD,     ONLY : AD66
      USE DIAG_MOD,     ONLY : AD67
      USE FILE_MOD,     ONLY : IOERROR
      USE FILE_MOD,     ONLY : IU_A3
      USE TIME_MOD,     ONLY : SET_CT_A3
      USE TIME_MOD,     ONLY : TIMESTAMP_STRING
      USE TRANSFER_MOD, ONLY : TRANSFER_A6
      USE TRANSFER_MOD, ONLY : TRANSFER_3D_Lp1
      USE TRANSFER_MOD, ONLY : TRANSFER_3D
      USE TRANSFER_MOD, ONLY : TRANSFER_G5_PLE

#     include "CMN_SIZE"                                    ! Size parameters
#     include "CMN_DIAG"                                    ! ND66, LD66, ND67
!
! !INPUT PARAMETERS: 
!
      INTEGER, INTENT(IN)  :: NYMD                          ! YYYYMMDD & hhmmss
      INTEGER, INTENT(IN)  :: NHMS                          !  of desired data
!
! !OUTPUT PARAMETERS:
!
      ! Fields dimensioed as (I,J)
      INTEGER, INTENT(OUT) :: CLDTOPS (IIPAR,JJPAR        )   

      ! Fields dimensioned as (I,J,L)
      REAL*8,  INTENT(OUT) :: CMFMC   (IIPAR,JJPAR,LLPAR+1)
      REAL*8,  INTENT(OUT) :: DQRCU   (IIPAR,JJPAR,LLPAR  )
      REAL*8,  INTENT(OUT) :: DQRLSAN (IIPAR,JJPAR,LLPAR  )     
      REAL*8,  INTENT(OUT) :: DQIDTMST(IIPAR,JJPAR,LLPAR  )
      REAL*8,  INTENT(OUT) :: DQLDTMST(IIPAR,JJPAR,LLPAR  ) 
      REAL*8,  INTENT(OUT) :: DQVDTMST(IIPAR,JJPAR,LLPAR  ) 
      REAL*8,  INTENT(OUT) :: DTRAIN  (IIPAR,JJPAR,LLPAR  )  
      REAL*8,  INTENT(OUT) :: PFICU   (IIPAR,JJPAR,LLPAR  )         
      REAL*8,  INTENT(OUT) :: PFILSAN (IIPAR,JJPAR,LLPAR  )           
      REAL*8,  INTENT(OUT) :: PFLCU   (IIPAR,JJPAR,LLPAR  )
      REAL*8,  INTENT(OUT) :: PFLLSAN (IIPAR,JJPAR,LLPAR  )
      REAL*8,  INTENT(OUT) :: QI      (IIPAR,JJPAR,LLPAR  )      
      REAL*8,  INTENT(OUT) :: QL      (IIPAR,JJPAR,LLPAR  )      
      REAL*8,  INTENT(OUT) :: QV      (IIPAR,JJPAR,LLPAR  )
      REAL*8,  INTENT(OUT) :: REEVAPCN(IIPAR,JJPAR,LLPAR  )
      REAL*8,  INTENT(OUT) :: REEVAPLS(IIPAR,JJPAR,LLPAR  )
      REAL*8,  INTENT(OUT) :: T       (IIPAR,JJPAR,LLPAR  )          
      REAL*8,  INTENT(OUT) :: TAUCLI  (IIPAR,JJPAR,LLPAR  )  
      REAL*8,  INTENT(OUT) :: TAUCLW  (IIPAR,JJPAR,LLPAR  )  
      REAL*8,  INTENT(OUT) :: U       (IIPAR,JJPAR,LLPAR  )       
      REAL*8,  INTENT(OUT) :: V       (IIPAR,JJPAR,LLPAR  )   

      ! Fields dimensioned as (L,I,J)
      REAL*8,  INTENT(OUT) :: CLOUD   (LLPAR,IIPAR,JJPAR  )       
      REAL*8,  INTENT(OUT) :: MOISTQ  (LLPAR,IIPAR,JJPAR  )    
      REAL*8,  INTENT(OUT) :: OPTDEPTH(LLPAR,IIPAR,JJPAR  )  
! 
! !REVISION HISTORY: 
!  20 Aug 2010 - R. Yantosca - Initial version, based on a3_read_mod.f
!  20 Aug 2010 - R. Yantosca - Now save CLDTOPS to ND67 diagnostic
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES
!
      ! Scalars
      INTEGER           :: I,   J,      K
      INTEGER           :: L,   XYMD,   XHMS
      INTEGER           :: IOS, NFOUND, N_A3
      REAL*8            :: C1,  C2
      CHARACTER(LEN=8)  :: NAME
      CHARACTER(LEN=16) :: STAMP

      ! Arrays
      REAL*4            :: D (IGLOB,JGLOB,LGLOB  )       
      REAL*4            :: D1(IGLOB,JGLOB,LGLOB+1)       

      !=================================================================
      ! READ_A3 begins here!      
      !=================================================================

      ! Zero number of fields that we have found
      NFOUND = 0

      !=================================================================
      ! Read the A-6 fields from disk
      !=================================================================
      DO

         ! A-6 field name
         READ( IU_A3, IOSTAT=IOS ) NAME

         ! IOS < 0: End-of-file; make sure we've found 
         ! all the A-6 fields before exiting this loop
         IF ( IOS < 0 ) THEN
            CALL A3_CHECK( NFOUND, N_A3_FIELDS )
            EXIT
         ENDIF

         ! IOS > 0: True I/O Error, stop w/ error msg 
         IF ( IOS > 0 ) CALL IOERROR( IOS, IU_A3, 'read_a3:1' )

         ! CASE statement for A-6 fields
         SELECT CASE ( TRIM( NAME ) )

            !-----------------------------------------------
            ! CLOUD: 3-D cloud fraction
            !-----------------------------------------------
            CASE ( 'CLOUD' ) 
               READ( IU_A3, IOSTAT=IOS ) XYMD, XHMS, D
               IF ( IOS /= 0 ) CALL IOERROR( IOS, IU_A3, 'read_a3:2' )

               IF ( XYMD == NYMD .and. XHMS == NHMS ) THEN
                  CALL TRANSFER_A6( D, CLOUD )
                  NFOUND = NFOUND + 1 
               ENDIF

            !-----------------------------------------------
            ! CMFMC: cloud mass flux [kg/m2/s]
            !-----------------------------------------------
            CASE ( 'CMFMC' ) 
               READ( IU_A3, IOSTAT=IOS ) XYMD, XHMS, D1
               IF ( IOS /= 0 ) CALL IOERROR( IOS, IU_A3, 'read_a3:3' )

               IF ( XYMD == NYMD .and. XHMS == NHMS ) THEN
                  CALL TRANSFER_3D_Lp1( D1, CMFMC )
                  NFOUND = NFOUND + 1 
               ENDIF

            !------------------------------------------------
            ! DQIDTMST: ice tendency in moist proc [kg/kg/s]
            !------------------------------------------------
            CASE ( 'DQIDTMST' ) 
               READ( IU_A3, IOSTAT=IOS ) XYMD, XHMS, D
               IF ( IOS /= 0 ) CALL IOERROR( IOS, IU_A3, 'read_a3:4' )
 
               IF ( XYMD == NYMD .and. XHMS == NHMS ) THEN
                  CALL TRANSFER_3D( D, DQIDTMST )
                  NFOUND = NFOUND + 1
               ENDIF

            !------------------------------------------------
            ! DQLDTMST: liquid tend in moist proc [kg/kg/s]
            !------------------------------------------------
            CASE ( 'DQLDTMST' ) 
               READ( IU_A3, IOSTAT=IOS ) XYMD, XHMS, D
               IF ( IOS /= 0 ) CALL IOERROR( IOS, IU_A3, 'read_a3:5' )
 
               IF ( XYMD == NYMD .and. XHMS == NHMS ) THEN
                  CALL TRANSFER_3D( D, DQLDTMST )
                  NFOUND = NFOUND + 1
               ENDIF

            !------------------------------------------------
            ! DQRLCU: ice tendency in moist proc [kg/kg/s]
            !------------------------------------------------
            CASE ( 'DQRCU' ) 
               READ( IU_A3, IOSTAT=IOS ) XYMD, XHMS, D
               IF ( IOS /= 0 ) CALL IOERROR( IOS, IU_A3, 'read_a3:6' )
 
               IF ( XYMD == NYMD .and. XHMS == NHMS ) THEN
                  CALL TRANSFER_3D( D, DQRCU )
                  NFOUND = NFOUND + 1
               ENDIF

            !------------------------------------------------
            ! DQRLSAN: ice tendency in moist proc [kg/kg/s]
            !------------------------------------------------
            CASE ( 'DQRLSAN' ) 
               READ( IU_A3, IOSTAT=IOS ) XYMD, XHMS, D
               IF ( IOS /= 0 ) CALL IOERROR( IOS, IU_A3, 'read_a3:7' )
 
               IF ( XYMD == NYMD .and. XHMS == NHMS ) THEN
                  CALL TRANSFER_3D( D, DQRLSAN )
                  NFOUND = NFOUND + 1
               ENDIF

            !------------------------------------------------
            ! DQVDTMST: vapor tend in moist proc [kg/kg/s]
            !------------------------------------------------
            CASE ( 'DQVDTMST' ) 
               READ( IU_A3, IOSTAT=IOS ) XYMD, XHMS, D
               IF ( IOS /= 0 ) CALL IOERROR( IOS, IU_A3, 'read_a3:8' )

               IF ( XYMD == NYMD .and. XHMS == NHMS ) THEN
                  CALL TRANSFER_3D( D, DQVDTMST )
                  NFOUND = NFOUND + 1
               ENDIF

            !------------------------------------------------
            ! DTRAIN: detrainment mass flux [kg/m2/s]
            !------------------------------------------------
            CASE ( 'DTRAIN' ) 
               READ( IU_A3, IOSTAT=IOS ) XYMD, XHMS, D
               IF ( IOS /= 0 ) CALL IOERROR( IOS, IU_A3, 'read_a3:9' )
 
               IF ( XYMD == NYMD .and. XHMS == NHMS ) THEN
                  CALL TRANSFER_3D( D, DTRAIN )
                  NFOUND = NFOUND + 1
               ENDIF

            !------------------------------------------------
            ! MOISTQ: tendency of spec. humidity [kg/kg/s]
            !------------------------------------------------
            CASE ( 'MOISTQ' ) 
               READ( IU_A3, IOSTAT=IOS ) XYMD, XHMS, D
               IF ( IOS /= 0 ) CALL IOERROR( IOS, IU_A3, 'read_a3:10' )

               IF ( XYMD == NYMD .and. XHMS == NHMS ) THEN
                  CALL TRANSFER_A6( D, MOISTQ )
                  NFOUND = NFOUND + 1 
               ENDIF

            !------------------------------------------------
            ! OPTDEPTH: in-cloud optical depth [unitless]
            !------------------------------------------------
            CASE ( 'OPTDEPTH' ) 
               READ( IU_A3, IOSTAT=IOS ) XYMD, XHMS, D
               IF ( IOS /= 0 ) CALL IOERROR( IOS, IU_A3, 'read_a3:11' )

               IF ( XYMD == NYMD .and. XHMS == NHMS ) THEN
                  CALL TRANSFER_A6( D, OPTDEPTH )
                  NFOUND = NFOUND + 1 
               ENDIF

            !------------------------------------------------
            ! PFICU: Dwn flx ice precip: conv [kg/m2/s]
            !------------------------------------------------
            CASE ( 'PFICU' ) 
               READ( IU_A3, IOSTAT=IOS ) XYMD, XHMS, D
               IF ( IOS /= 0 ) CALL IOERROR( IOS, IU_A3, 'read_a3:12' )

               IF ( XYMD == NYMD .and. XHMS == NHMS ) THEN
                  CALL TRANSFER_3D( D, PFICU )
                  NFOUND = NFOUND + 1 
               ENDIF

            !------------------------------------------------
            ! PFILSAN: Dwn flx ice precip: LS+anv [kg/m2/s]
            !------------------------------------------------
            CASE ( 'PFILSAN' ) 
               READ( IU_A3, IOSTAT=IOS ) XYMD, XHMS, D
               IF ( IOS /= 0 ) CALL IOERROR( IOS, IU_A3, 'read_a3:13' )

               IF ( XYMD == NYMD .and. XHMS == NHMS ) THEN
                  CALL TRANSFER_3D( D, PFILSAN )
                  NFOUND = NFOUND + 1 
               ENDIF

            !------------------------------------------------
            ! PFLCU: Dwn flx liq precip: conv [kg/m2/s]
            !------------------------------------------------
            CASE ( 'PFLCU' ) 
               READ( IU_A3, IOSTAT=IOS ) XYMD, XHMS, D
               IF ( IOS /= 0 ) CALL IOERROR( IOS, IU_A3, 'read_a3:14' )

               IF ( XYMD == NYMD .and. XHMS == NHMS ) THEN
                  CALL TRANSFER_3D( D, PFLCU )
                  NFOUND = NFOUND + 1 
               ENDIF

            !------------------------------------------------
            ! PFLLSAN: Dwn flx ice precip: LS+anv [kg/m2/s]
            !------------------------------------------------
            CASE ( 'PFLLSAN' ) 
               READ( IU_A3, IOSTAT=IOS ) XYMD, XHMS, D
               IF ( IOS /= 0 ) CALL IOERROR( IOS, IU_A3, 'read_a3:15' )

               IF ( XYMD == NYMD .and. XHMS == NHMS ) THEN
                  CALL TRANSFER_3D( D, PFLLSAN )
                  NFOUND = NFOUND + 1 
               ENDIF

            !------------------------------------------------
            ! QI: Cloud ice mixing ratio [kg/kg]
            !------------------------------------------------
            CASE ( 'QI' ) 
               READ( IU_A3, IOSTAT=IOS ) XYMD, XHMS, D
               IF ( IOS /= 0 ) CALL IOERROR( IOS, IU_A3, 'read_a3:16' )
            
               IF ( XYMD == NYMD .and. XHMS == NHMS ) THEN
                  CALL TRANSFER_3D( D, QI )
                  NFOUND = NFOUND + 1 
               ENDIF
            
            !------------------------------------------------
            ! QL: Cloud water mixing ratio [kg/kg]
            !------------------------------------------------
            CASE ( 'QL' ) 
               READ( IU_A3, IOSTAT=IOS ) XYMD, XHMS, D
               IF ( IOS /= 0 ) CALL IOERROR( IOS, IU_A3, 'read_a3:17' )
            
               IF ( XYMD == NYMD .and. XHMS == NHMS ) THEN
                  CALL TRANSFER_3D( D, QL )
                  NFOUND = NFOUND + 1 
               ENDIF

            !------------------------------------------------
            ! QV: Specific humidity [kg/kg]
            !------------------------------------------------
            CASE ( 'QV' ) 
               READ( IU_A3, IOSTAT=IOS ) XYMD, XHMS, D
               IF ( IOS /= 0 ) CALL IOERROR( IOS, IU_A3, 'read_a3:18' )

               IF ( XYMD == NYMD .and. XHMS == NHMS ) THEN
                  CALL TRANSFER_3D( D, QV )
                  NFOUND = NFOUND + 1 

                  ! NOTE: Now set negative Q to a small positive # 
                  ! instead of zero, so as not to blow up logarithms
                  ! (bmy, 9/8/06)
                  WHERE ( QV < 0d0 ) QV = 1d-32
               ENDIF

            !------------------------------------------------
            ! REEVAPCN: Evap, prec cndsate: conv [kg/kg/s]
            !------------------------------------------------
            CASE ( 'REEVAPCN' ) 
               READ( IU_A3, IOSTAT=IOS ) XYMD, XHMS, D
               IF ( IOS /= 0 ) CALL IOERROR( IOS, IU_A3, 'read_a3:19' )

               IF ( XYMD == NYMD .and. XHMS == NHMS ) THEN
                  CALL TRANSFER_3D( D, REEVAPCN )
                  NFOUND = NFOUND + 1 
               ENDIF

            !------------------------------------------------
            ! REEVAPLS: Evap, prec cndsate: LS+anv [kg/kg/s]
            !------------------------------------------------
            CASE ( 'REEVAPLS' ) 
               READ( IU_A3, IOSTAT=IOS ) XYMD, XHMS, D
               IF ( IOS /= 0 ) CALL IOERROR( IOS, IU_A3, 'read_a3:20' )

               IF ( XYMD == NYMD .and. XHMS == NHMS ) THEN
                  CALL TRANSFER_3D( D, REEVAPLS )
                  NFOUND = NFOUND + 1 
               ENDIF

            !------------------------------------------------
            ! T: 3-D temperature [K]
            !------------------------------------------------
            CASE ( 'T' ) 
               READ( IU_A3, IOSTAT=IOS ) XYMD, XHMS, D
               IF ( IOS /= 0 ) CALL IOERROR( IOS, IU_A3, 'read_a3:21' )

               IF ( XYMD == NYMD .and. XHMS == NHMS ) THEN
                  CALL TRANSFER_3D( D, T )
                  NFOUND = NFOUND + 1 
               ENDIF

            !------------------------------------------------
            ! TAUCLI: in-cld ice optical depth [unitless]
            !------------------------------------------------
            CASE ( 'TAUCLI' ) 
               READ( IU_A3, IOSTAT=IOS ) XYMD, XHMS, D
               IF ( IOS /= 0 ) CALL IOERROR( IOS, IU_A3, 'read_a3:22' )

               IF ( XYMD == NYMD .and. XHMS == NHMS ) THEN
                  CALL TRANSFER_3D( D, TAUCLI )
                  NFOUND = NFOUND + 1 
               ENDIF

            !------------------------------------------------
            ! TAUCLW: in-cld water optical depth [unitless]
            !------------------------------------------------
            CASE ( 'TAUCLW' ) 
               READ( IU_A3, IOSTAT=IOS ) XYMD, XHMS, D
               IF ( IOS /= 0 ) CALL IOERROR( IOS, IU_A3, 'read_a3:23' )

               IF ( XYMD == NYMD .and. XHMS == NHMS ) THEN
                  CALL TRANSFER_3D( D, TAUCLW )
                  NFOUND = NFOUND + 1 
               ENDIF

            !------------------------------------------------
            ! U: Eastward component of wind [m/s]
            !------------------------------------------------
            CASE ( 'U' ) 
               READ( IU_A3, IOSTAT=IOS ) XYMD, XHMS, D
               IF ( IOS /= 0 ) CALL IOERROR( IOS, IU_A3, 'read_a3:24' )

               IF ( XYMD == NYMD .and. XHMS == NHMS ) THEN
                  CALL TRANSFER_3D( D, U )
                  NFOUND = NFOUND + 1 
               ENDIF

            !------------------------------------------------
            ! V: Northward component of wind [m/s]
            !------------------------------------------------
            CASE ( 'V' ) 
               READ( IU_A3, IOSTAT=IOS ) XYMD, XHMS, D
               IF ( IOS /= 0 ) CALL IOERROR( IOS, IU_A3, 'read_a3:25' )

               IF ( XYMD == NYMD .and. XHMS == NHMS ) THEN
                  CALL TRANSFER_3D( D, V )
                  NFOUND = NFOUND + 1 
               ENDIF

            !------------------------------------------------
            ! Field not found -- skip over
            !------------------------------------------------
            CASE DEFAULT
               WRITE ( 6, 200 )

         END SELECT

         !==============================================================
         ! If we have found all the fields for this time, then exit 
         ! the loop.  Otherwise, go on to the next iteration.
         !==============================================================
         IF ( XYMD == NYMD .and. XHMS == NHMS ) THEN
            IF ( NFOUND == N_A3_FIELDS ) THEN
               STAMP = TIMESTAMP_STRING( NYMD, NHMS )
               WRITE( 6, 210 ) NFOUND, STAMP
               EXIT
            ENDIF
         ENDIF
      ENDDO

      ! FORMATs
 200  FORMAT( 'Searching for next MERRA A3 field!'                    )
 210  FORMAT( '     - Found all ', i3, ' MERRA A3 met fields for ', a )

      !=================================================================
      !        %%%%% SPECIAL HANDLING FOR CERTAIN FIELDS %%%%% 
      !=================================================================

      ! CLDTOPS highest location of CMFMC in the column (I,J)
      DO J = 1, JJPAR
      DO I = 1, IIPAR
         K = 1
         DO L = 1, LLPAR
            IF ( CMFMC(I,J,L) > 0d0 ) THEN
               K = K + 1
            ENDIF
         ENDDO
         CLDTOPS(I,J) = K
      ENDDO
      ENDDO

      ! Convert MERRA specific humidity from [kg/kg] to [g/kg]
      QV = QV * 1000d0

      ! MOISTQ < 0 denotes precipitation.  Convert negative values to
      ! positives, and then divide by 8.64d7 to convert to units of
      ! [kg H2O/kg air/s].  (bmy, 4/5/99)
      MOISTQ = -MOISTQ / 8.64d7

      !=================================================================
      !          %%%%% ND66 diagnostic: 3-D met fields %%%%%
      !
      ! (1 ) UWND   : 6-h average U-winds             [m/s]
      ! (2 ) VWND   : 6=h average V-winds             [m/s]
      ! (3 ) TMPU   : 6-h average Temperature         [K]
      ! (4 ) SPHU   : 6-h average Specific humidity   [g H20/kg air]   
      ! (5 ) CMFMC  : Convective Mass Flux            [kg/m2/s] 
      ! (6 ) DTRAIN : Detrainment mass flux           [kg/m2/s]
      !=================================================================
      IF ( ND66 > 0 ) THEN
         AD66(:,:,1:LD66,1) = AD66(:,:,1:LD66,1) + U     (:,:,1:LD66)
         AD66(:,:,1:LD66,2) = AD66(:,:,1:LD66,2) + V     (:,:,1:LD66)
         AD66(:,:,1:LD66,3) = AD66(:,:,1:LD66,3) + T     (:,:,1:LD66)
         AD66(:,:,1:LD66,4) = AD66(:,:,1:LD66,4) + QV    (:,:,1:LD66)
         AD66(:,:,1:LD66,5) = AD66(:,:,1:LD66,5) + CMFMC (:,:,1:LD66)
         AD66(:,:,1:LD66,6) = AD66(:,:,1:LD66,6) + DTRAIN(:,:,1:LD66)
      ENDIF

      !=================================================================
      !          %%%%% ND67 diagnostic: 2-D met fields %%%%%
      !=================================================================
      IF ( ND67 > 0 ) THEN
         AD67(:,:,16) = AD67(:,:,16) + CLDTOPS  ! Max cld top height [levels]
      ENDIF

      !=================================================================
      ! Cleanup and quit
      !=================================================================

      ! Increment the # of times A3 fields have been read
      CALL SET_CT_A3( INCREMENT=.TRUE. )

      END SUBROUTINE READ_A3
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: a3_check
!
! !DESCRIPTION: Subroutine A3\_CHECK prints an error message if not all of the 
!  A-6 met fields are found.  The run is also terminated. 
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE A3_CHECK( NFOUND, N_A3 )
!
! !USES:
!
      USE ERROR_MOD, ONLY : GEOS_CHEM_STOP
!
! !INPUT PARAMETERS: 
!
      INTEGER, INTENT(IN) :: NFOUND   ! # of fields found in file
      INTEGER, INTENT(IN) :: N_A3     ! # of expected fields
! 
! !REVISION HISTORY: 
!  20 Aug 2010 - R. Yantosca - Initial version, based on a6_read_mod.f
!EOP
!------------------------------------------------------------------------------
!BOC

      ! Test if N_FOUND == N_A3
      IF ( NFOUND /= N_A3 ) THEN

         ! Write error msg
         WRITE( 6, '(a)' ) REPEAT( '=', 79 )
         WRITE( 6, 100   ) 
         WRITE( 6, 110   ) N_A3, NFOUND
         WRITE( 6, 120   )
         WRITE( 6, '(a)' ) REPEAT( '=', 79 )

         ! FORMATs
 100     FORMAT( 'ERROR -- not enough MERRA A3 fields found!' )
 110     FORMAT( 'There are ', i2, ' fields but only ', i2 ,
     &           ' were found!'                               )
 120     FORMAT( '### STOP in A3_CHECK (merra_a3_mod.f)'      )

         ! Deallocate arrays and stop
         CALL GEOS_CHEM_STOP

      ENDIF

      END SUBROUTINE A3_CHECK
!EOC
      END MODULE MERRA_A3_MOD
