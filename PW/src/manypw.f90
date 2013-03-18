!
! Copyright (C) 2013 Quantum ESPRESSO group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!----------------------------------------------------------------------------
PROGRAM manypw
  !----------------------------------------------------------------------------
  !
  ! ... Poor-man pw.x parallel launcher. Usage (for mpirun):
  ! ...    mpirun -np Np many.x -ni Ni [other options]
  ! ... or whatever is appropriate for your parallel environment
  ! ... Starts Ni pw.x instances each running on Np/Ni processors
  ! ... Each pw.x instances
  ! ... * reads input data from from pw_N.in, N=0,..,,Ni-1 if no input
  ! ...   file is specified via the -i option; from "input_file"_N
  ! ...   if command-line options -i "input_file" is specified
  ! ... * saves temporary and final data to "outdir"_N/ directory
  ! ...   (or to tmp_N/ if outdir='./')
  ! ... * writes output to pw_N.out in the current directory if no input
  ! ...   file is specified via the -i option; to "input_file"_N.out
  ! ...   if command-line options -i "input_file" is specified
  !
  USE input_parameters,  ONLY : outdir
  USE environment,       ONLY : environment_start, environment_end
  USE io_global,         ONLY : ionode, ionode_id, stdout
  USE mp_global,         ONLY : mp_startup, my_image_id
  USE read_input,        ONLY : read_input_file
  USE command_line_options, ONLY: input_file_
  !
  IMPLICIT NONE
  !
  INTEGER :: i
  LOGICAL :: opnd
  CHARACTER(LEN=256) :: filename
  CHARACTER(LEN=7) :: image_label
  CHARACTER(LEN=6), EXTERNAL :: int_to_char
  !
  !
#ifdef __MPI
  CALL mp_startup ( start_images=.true. )
#endif
  !
  CALL environment_start ( 'MANYPW' )
  !
  ! ... Image-specific input files
  !
  image_label = '_' // int_to_char(my_image_id)
  IF ( TRIM (input_file_) == ' ') THEN
     filename = 'pw' // TRIM(image_label)  // '.in'
  ELSE
     filename = TRIM(input_file_) // TRIM(image_label) 
  END IF
  !
  CALL read_input_file ( prog='PW', input_file_=filename )
  !
  ! ... Here open image-specific output files
  !
  IF ( ionode ) THEN
     !
     INQUIRE ( UNIT = stdout, OPENED = opnd )
     IF (opnd) CLOSE ( UNIT = stdout )
     IF ( TRIM (input_file_) == ' ') THEN
        filename = 'pw' // TRIM(image_label)  // '.out'
     ELSE
        filename = TRIM(input_file_) // TRIM(image_label) // '.out'
     END IF
     OPEN( UNIT = stdout, FILE = TRIM(filename), STATUS = 'UNKNOWN' )
     !
  END IF
  !
  ! ... Set image-specific value for "outdir", starting from input value
  ! ... (read in read_input_file)
  !
  DO i=LEN_TRIM(outdir),1,-1
     IF ( outdir(i:i) /= '/' .AND. outdir(i:i) /= '.' ) EXIT
  END DO
  ! ... i = position of last character different from '/' and '.'
  IF ( i == 0 ) THEN
     outdir = 'tmp' // trim(image_label) // '/'
  ELSE
     outdir = outdir(1:i) // trim(image_label) // '/'
  END IF
  !
  ! ... Perform actual calculation
  !
  CALL run_pwscf  ( )
  !
  STOP
  !
END PROGRAM manypw