! MIT License
!
! Copyright (c) 2010-present David A. Kopriva and other contributors: AUTHORS.md
!
! Permission is hereby granted, free of charge, to any person obtaining a copy  
! of this software and associated documentation files (the "Software"), to deal  
! in the Software without restriction, including without limitation the rights  
! to use, copy, modify, merge, publish, distribute, sublicense, and/or sell  
! copies of the Software, and to permit persons to whom the Software is  
! furnished to do so, subject to the following conditions:
!
! The above copyright notice and this permission notice shall be included in all  
! copies or substantial portions of the Software.
!
! THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR  
! IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  
! FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE  
! AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER  
! LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,  
! OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE  
! SOFTWARE.
! 
! HOHQMesh contains code that, to the best of our knowledge, has been released as
! public domain software:
! * `b3hs_hash_key_jenkins`: originally by Rich Townsend, 
!    https://groups.google.com/forum/#!topic/comp.lang.fortran/RWoHZFt39ng, 2005
! * `fmin`: originally by George Elmer Forsythe, Michael A. Malcolm, Cleve B. Moler, 
!    Computer Methods for Mathematical Computations, 1977
! * `spline`: originally by George Elmer Forsythe, Michael A. Malcolm, Cleve B. Moler, 
!    Computer Methods for Mathematical Computations, 1977
! * `seval`: originally by George Elmer Forsythe, Michael A. Malcolm, Cleve B. Moler, 
!    Computer Methods for Mathematical Computations, 1977
!
! --- End License
!
!////////////////////////////////////////////////////////////////////////
!
!      SimpleSweep.f90
!      Created: March 28, 2013 9:55 AM 
!      By: David Kopriva  
!
!     Take a quad mesh generated by the SpecMesh2D code and
!     extrude it vertically in the "z" direction to create a
!     3D Hex mesh or rotate it about the x-axis to generate
!     a volume of revolution.
!
!      SIMPLE_EXTRUSION contains the keys
!         direction
!         height
!         subdivisions
!         start surface name
!         end surface name
!
!      SIMPLE_ROTATION contains the keys
!
!         direction
!         rotation angle factor
!         subdivisions 
!         start surface name
!         end surface name
!
!////////////////////////////////////////////////////////////////////////
!
      Module SimpleSweepModule
      USE FTValueDictionaryClass
      USE SMConstants
      USE ProgramGlobals
      USE FTExceptionClass
      USE SharedExceptionManagerModule
      USE HexMeshObjectsModule
      USE ErrorTypesModule
      IMPLICIT NONE 
! 
!--------------------------------------------------------------- 
! Define methods to generate a 3D mesh from a 2D one by straight
! line extrusion or simple rotation
!---------------------------------------------------------------
! 
      
      INTEGER, PARAMETER :: SWEEP_FLOOR = 1, SWEEP_CEILING = 2
!
!     ------------------------------------------------------------
!     Given the global node ID, get the level and 2D node location
!     in the nodes array
!     ------------------------------------------------------------
!
      INTEGER, ALLOCATABLE, PRIVATE  :: locAndLevelForNodeID(:,:)
      
!     ========      
      CONTAINS 
!     ========      
!
!////////////////////////////////////////////////////////////////////////
!
      SUBROUTINE CheckSimpleExtrusionBlock( dict ) 
!
!        Example block is:
!
!            \begin{SIMPLE_EXTRUSION}
!               direction          = 1 = x, 2 = y, 3 = z
!               height             = 10.0
!               subdivisions       = 5
!               start surface name = "bottom"
!               end surface name   = "top"
!            \end{SIMPLE_EXTRUSION}
!
         IMPLICIT NONE
!
!        ---------
!        Arguments
!        ---------
!
         CLASS(FTValueDictionary) :: dict
!
!        ---------------
!        Local variables
!        ---------------
!
         INTEGER      , EXTERNAL                :: GetIntValue
         REAL(KIND=RP), EXTERNAL                :: GetRealValue
         CHARACTER( LEN=LINE_LENGTH ), EXTERNAL :: GetStringValue
!
!        ---------
!        Direction
!        ---------
!
         IF ( .NOT. dict % containsKey(key = SIMPLE_SWEEP_DIRECTION_KEY) )     THEN
            CALL ThrowErrorExceptionOfType(poster = "CheckSimpleExtrusionBlock", &
                                           msg = "key " // TRIM(SIMPLE_SWEEP_DIRECTION_KEY) // " not found in extrusion block", &
                                           typ = FT_ERROR_FATAL) 
         END IF
!
!        ------
!        Height
!        ------
!
         IF ( .NOT. dict % containsKey(key = SIMPLE_EXTRUSION_HEIGHT_KEY) )     THEN
            CALL ThrowErrorExceptionOfType(poster = "CheckSimpleExtrusionBlock", &
                                           msg = "key " // TRIM(SIMPLE_EXTRUSION_HEIGHT_KEY) // " not found in extrusion block", &
                                           typ = FT_ERROR_FATAL) 
         END IF
!
!        ------------
!        Subdivisions
!        ------------
!
         IF ( .NOT. dict % containsKey(key = SIMPLE_SWEEP_SUBDIVISIONS_KEY) )     THEN
            CALL ThrowErrorExceptionOfType(poster = "CheckSimpleExtrusionBlock", &
                                           msg = "key " // TRIM(SIMPLE_SWEEP_SUBDIVISIONS_KEY) // " not found in extrusion block", &
                                           typ = FT_ERROR_FATAL) 
         END IF
!
!        -------------------
!        Bottom surface name
!        -------------------
!
         IF ( .NOT. dict % containsKey(key = SIMPLE_SWEEP_STARTNAME_KEY) )     THEN
            CALL ThrowErrorExceptionOfType(poster = "CheckSimpleExtrusionBlock", &
                                           msg = "key " // TRIM(SIMPLE_SWEEP_STARTNAME_KEY) // " not found in extrusion block", &
                                           typ = FT_ERROR_FATAL) 
         END IF
!
!        ----------------
!        Top surface name
!        ----------------
!
         IF ( .NOT. dict % containsKey(key = SIMPLE_SWEEP_ENDNAME_KEY) )     THEN
            CALL ThrowErrorExceptionOfType(poster = "CheckSimpleExtrusionBlock", &
                                           msg = "key " // TRIM(SIMPLE_SWEEP_ENDNAME_KEY) // " not found in extrusion block", &
                                           typ = FT_ERROR_FATAL) 
         END IF

      END SUBROUTINE CheckSimpleExtrusionBlock
!
!////////////////////////////////////////////////////////////////////////
!
      SUBROUTINE CheckSimpleRotationBlock( dict ) 
!
!        Example block is:
!
!            \begin{SIMPLE_ROTATION}
!               direction               = 1 = x, 2 = y, 3 = z
!               rotation angle factor   = 0.5
!               subdivisions            = 5
!               start surface name      = "bottom"
!               end surface name        = "top"
!            \end{SIMPLE_ROTATION}
!
         IMPLICIT NONE
!
!        ---------
!        Arguments
!        ---------
!
         CLASS(FTValueDictionary) :: dict
!
!        ---------------
!        Local variables
!        ---------------
!
         REAL(KIND=RP)                          :: angleFactor
         INTEGER      , EXTERNAL                :: GetIntValue
         REAL(KIND=RP), EXTERNAL                :: GetRealValue
         CHARACTER( LEN=LINE_LENGTH ), EXTERNAL :: GetStringValue
!
!        ---------
!        Direction
!        ---------
!
         IF ( .NOT. dict % containsKey(key = SIMPLE_SWEEP_DIRECTION_KEY) )     THEN
            CALL ThrowErrorExceptionOfType(poster = "CheckSimpleRotationBlock", &
                                           msg = "key " // TRIM(SIMPLE_SWEEP_DIRECTION_KEY) // " not found in rotation block", &
                                           typ = FT_ERROR_FATAL) 
         END IF
!
!        ----------------------
!        Angle (Fraction of PI)
!        ----------------------
!
         IF ( dict % containsKey(key = SIMPLE_ROTATION_ANGLE_FRAC_KEY) )     THEN
            angleFactor = dict % doublePrecisionValueForKey(key = SIMPLE_ROTATION_ANGLE_FRAC_KEY)
            CALL dict % addValueForKey(angleFactor,SIMPLE_ROTATION_ANGLE_KEY)
         ELSE 
            CALL ThrowErrorExceptionOfType(poster = "CheckSimpleRotationBlock", &
                                           msg = "key " // TRIM(SIMPLE_ROTATION_ANGLE_FRAC_KEY) // " not found in rotation block", &
                                           typ = FT_ERROR_FATAL) 
         END IF
!
!        ------------
!        Subdivisions
!        ------------
!
         IF ( .NOT. dict % containsKey(key = SIMPLE_SWEEP_SUBDIVISIONS_KEY) )     THEN
            CALL ThrowErrorExceptionOfType(poster = "CheckSimpleRotationBlock", &
                                           msg = "key " // TRIM(SIMPLE_SWEEP_SUBDIVISIONS_KEY) // " not found in rotation block", &
                                           typ = FT_ERROR_FATAL) 
         END IF
!
!        -------------------
!        Bottom surface name
!        -------------------
!
         IF ( .NOT. dict % containsKey(key = SIMPLE_SWEEP_STARTNAME_KEY) )     THEN
            CALL ThrowErrorExceptionOfType(poster = "CheckSimpleRotationBlock", &
                                           msg = "key " // TRIM(SIMPLE_SWEEP_STARTNAME_KEY) // " not found in rotation block", &
                                           typ = FT_ERROR_FATAL) 
         END IF
!
!        ----------------
!        Top surface name
!        ----------------
!
         IF ( .NOT. dict % containsKey(key = SIMPLE_SWEEP_ENDNAME_KEY) )     THEN
            CALL ThrowErrorExceptionOfType(poster = "CheckSimpleRotationBlock", &
                                           msg = "key " // TRIM(SIMPLE_SWEEP_ENDNAME_KEY) // " not found in rotation block", &
                                           typ = FT_ERROR_FATAL) 
         END IF

      END SUBROUTINE CheckSimpleRotationBlock
!
!//////////////////////////////////////////////////////////////////////// 
! 
      SUBROUTINE PerformSimpleMeshSweep( project, pMutation, h, parametersDictionary )
         USE MeshProjectClass
         IMPLICIT NONE
!
!        ---------
!        Arguments
!        ---------
!
         TYPE ( MeshProject )        :: project
         CLASS( FTValueDictionary )  :: parametersDictionary
         INTEGER                     :: pMutation
         REAL(KIND=RP)               :: h
!
!        ---------------
!        Local Variables
!        ---------------
!
         TYPE (SMMesh)              , POINTER :: quadMesh
         TYPE (FTMutableObjectArray), POINTER :: quadElementsArray
         
         INTEGER                :: numberOfLayers
         INTEGER                :: numberOf2DNodes, numberOfQuadElements
         INTEGER                :: numberOfNodes
         INTEGER                :: node2DID
         INTEGER                :: N
         
         
         TYPE(SMNodePtr)   , DIMENSION(:), ALLOCATABLE :: quadMeshNodes
         CLASS(SMNode)                   , POINTER     :: currentNode
         CLASS(FTObject)                 , POINTER     :: obj
!                  
!
         quadMesh              => project % mesh
         N                     =  project % runParams % polynomialOrder
         numberOfQuadElements  =  project % hexMesh % numberOfQuadElements
         numberOfLayers        =  project % hexMesh % numberOfLayers
         numberOf2DNodes       =  quadMesh % nodes % count()
!
!        ---------------------------------------------------------------
!        Make sure that the nodes and elements are consecutively ordered
!        and that the edges refer to the correct elements.
!        ---------------------------------------------------------------
!
         CALL quadMesh % renumberObjects(NODES)
         CALL quadMesh % renumberObjects(ELEMENTS)
         CALL quadMesh % renumberObjects(EDGES)
!
!        ---------------------------------------
!        Gather nodes for easy access
!        TODO: The list class now has a function
!        to return an array of the objects.
!        ---------------------------------------
!
         numberOfNodes   = numberOf2DNodes*(numberOfLayers + 1)
         ALLOCATE( quadMeshNodes(numberOf2DNodes) )
         
         CALL quadMesh % nodesIterator % setToStart()
         DO WHILE( .NOT.quadMesh % nodesIterator % isAtEnd())
         
            obj => quadMesh % nodesIterator % object()
            CALL castToSMNode(obj,currentNode)
            node2DID = currentNode % id
            quadMeshNodes(node2DID) % node => currentNode
         
            CALL quadMesh % nodesIterator % moveToNext() 
         END DO 
!
!        ---------------------------------------------------------------
!        Allocate connections between global ID and local (2D, level) id
!        ---------------------------------------------------------------
!
         ALLOCATE( locAndLevelForNodeID(2, numberOfNodes) )
!
!        ------------------------------
!        Sweep the skeleton of the mesh
!        ------------------------------
!
         CALL sweepNodes( quadMeshNodes, project % hexMesh, h, pMutation )
         CALL sweepElements( quadMesh, project % hexMesh, &
                             numberofLayers, parametersDictionary )
!
!        -------------------------------------
!        Sweep the internal degrees of freedom
!        -------------------------------------
!
         quadElementsArray => quadMesh % elements % allObjects()
         CALL SweepInternalDOFs(hex8Mesh          = project % hexMesh, &
                                quadElementsArray = quadElementsArray, &
                                N                 = N,                 &
                                h                 = h,                &
                                pmutation         = pMutation)
          
         CALL releaseFTMutableObjectArray(quadElementsArray)
         DEALLOCATE(quadMeshNodes)
!

      END SUBROUTINE PerformSimpleMeshSweep
!
!//////////////////////////////////////////////////////////////////////// 
! 
      SUBROUTINE sweepNodes( quadMeshNodes, hex8Mesh, h, pMutation )
         IMPLICIT NONE
!
!        ---------
!        Arguments
!        ---------
!
         TYPE ( StructuredHexMesh )    :: hex8Mesh
         REAL(KIND=RP)                 :: h
         TYPE(SMNodePtr), DIMENSION(:) :: quadMeshNodes
         INTEGER                       :: pMutation
!
!        ---------------
!        Local Variables
!        ---------------
!
         INTEGER         :: numberOf2DNodes
         INTEGER         :: nodeID
         INTEGER         :: j, k
         INTEGER         :: numberOfLayers
         REAL(KIND=RP)   :: z, xi
!
!        ---------------------------------------
!        Generate the new nodes for the hex mesh
!        layer by layer. Order the new node IDs
!        layer by layer, too.
!        ---------------------------------------
!
         numberOf2DNodes = SIZE(quadMeshNodes)
         numberOfLayers  = hex8Mesh % numberofLayers
                      
         nodeID = 1
         DO j = 0, numberofLayers

            DO k = 1, numberOf2DNodes
               hex8Mesh % nodes(k,j) % globalID = nodeID
!
!              ----------------------------------
!              Interpolate between top and bottom
!              ----------------------------------
!
               xi = DBLE(j)/DBLE(numberOfLayers)
               z  = quadMeshNodes(k) % node % x(pMutation)*(1.0_RP - xi) + h*xi
               hex8Mesh % nodes(k,j) % x  = extrudedNodeLocation(baseLocation = quadMeshNodes(k) % node % x, &
                                                                 delta        = z, &
                                                                 pmutation    = pMutation)
               locAndLevelForNodeID(1,nodeID) = k
               locAndLevelForNodeID(2,nodeID) = j
               nodeID = nodeID + 1
            END DO   
            
         END DO
!
      END SUBROUTINE sweepNodes
!
!//////////////////////////////////////////////////////////////////////// 
! 
      SUBROUTINE SweepInternalDOFs( hex8Mesh, quadElementsArray, N, h, pmutation)
         USE SMMeshClass
         USE FTMutableObjectArrayClass
         IMPLICIT NONE  
!
!        ---------
!        Arguments
!        ---------
!
         TYPE (FTMutableObjectArray), POINTER  :: quadElementsArray
         TYPE ( StructuredHexMesh )            :: hex8Mesh
         REAL(KIND=RP)                         :: h
         INTEGER                               :: pMutation
         INTEGER                               :: N
!
!        ---------------
!        Local Variables
!        ---------------
!
         INTEGER                   :: l, m, i, j, k, nLev
         REAL(KIND=RP)             :: x(3), z, y(3)
         REAL(KIND=RP)             :: delta, eta, xi
         CLASS(FTObject) , POINTER :: obj
         CLASS(SMElement), POINTER :: e
!
!        ------------------------------------------
!        Extend the face points on the quad element
!        up through the hex element.
!        ------------------------------------------
!
         nLev = hex8Mesh % numberofLayers
         
         DO l = 1, hex8Mesh % numberOfQuadElements
            obj => quadElementsArray % objectAtIndex(l)
            CALL castToSMelement(obj,e)
            DO m = 1, hex8Mesh % numberofLayers
               xi = DBLE(m-1)/DBLE(nLev)
               DO k = 0, N
                  eta = 0.5_RP*(1.0 - COS(k*PI/N))
                  DO j = 0, N 
                     DO i = 0, N
                        delta = (h - e % xPatch(pMutation,i,j))/nLev
                        z     = xi*h + (1.0_RP - xi)*e % xPatch(pMutation,i,j) + delta*eta
                        x     = permutePosition(x = e % xPatch(:,i,j),pmutation = pMutation)
                        y     = extrudedNodeLocation(baseLocation = x, delta = z, pmutation = pMutation)
                        
                        hex8Mesh % elements(l,m) % x(:,i,j,k) = y
                     END DO 
                  END DO 
               END DO 
            END DO   
         END DO
         
      END SUBROUTINE SweepInternalDOFs
!
!//////////////////////////////////////////////////////////////////////// 
! 
      SUBROUTINE sweepElements( quadMesh, hex8Mesh, numberofLayers, parametersDictionary )
!
!        -------------------------------
!        Call after generating the nodes
!        -------------------------------
!
         USE MeshProjectClass  
         IMPLICIT NONE
!
!        ---------
!        Arguments
!        ---------
!
         TYPE ( SMMesh )             :: quadMesh
         TYPE ( StructuredHexMesh )  :: hex8Mesh
         INTEGER                     :: numberOfLayers
         TYPE( FTValueDictionary)    :: parametersDictionary
!
!        ---------------
!        Local Variables
!        ---------------
!
         INTEGER   :: numberOfQuadElements
         INTEGER   :: elementID, nodeID, node2DID, quadElementID
         INTEGER   :: j, k
         INTEGER   :: flagMap(4) = [1,4,2,6]
         
         
         CLASS(SMNode)                   , POINTER     :: node
         CLASS(SMElement)                , POINTER     :: currentQuadElement
         CLASS(FTObject)                 , POINTER     :: obj
         
         numberOfQuadElements = hex8Mesh % numberOfQuadElements
!
!        ---------------------------------
!        Build the elements layer by layer
!        ---------------------------------
!
         elementID = 1
         DO j = 1, numberOfLayers
            quadElementID = 1
            
            CALL quadMesh % elementsIterator % setToStart()
            
            DO WHILE( .NOT. quadMesh % elementsIterator % isAtEnd() )
               obj => quadMesh % elementsIterator % object()
               CALL castToSMElement(obj,currentQuadElement)
!
!              -----------------------
!              Set the element nodeIDs
!              -----------------------
!
               DO k = 1, 4
!
!                 -------------
!                 Bottom of hex
!                 -------------
!
                  obj => currentQuadElement % nodes % objectAtIndex(k)
                  CALL cast(obj,node)
                  node2DID = node % id
                  nodeID   = hex8Mesh % nodes(node2DID,j-1) % globalID
                  hex8Mesh % elements(quadElementID,j) % nodeIDs(k) = nodeID
!
!                 ----------
!                 Top of hex
!                 ----------
!
                  nodeID = hex8Mesh % nodes(node2DID,j) % globalID
                  hex8Mesh % elements(quadElementID,j)  % nodeIDs(k+4) = nodeID
                  
               END DO
!
!              ------------------------------------------------------------------
!              Set boundary condition names at the start and end of the extrusion
!              as defined in the control file
!              ------------------------------------------------------------------
!
               IF ( j == 1 )     THEN
                  hex8Mesh % elements(quadElementID,j) % bFaceName(3) = &
                  parametersDictionary % stringValueForKey(key             = SIMPLE_SWEEP_STARTNAME_KEY,&
                                                           requestedLength = LINE_LENGTH)
               END IF 
               IF (j == numberOfLayers)     THEN 
                  hex8Mesh % elements(quadElementID,j) % bFaceName(5) = &
                  parametersDictionary % stringValueForKey(key             = SIMPLE_SWEEP_ENDNAME_KEY,&
                                                           requestedLength = LINE_LENGTH)
               END IF 
!
!              ----------------------------------------------------------------
!              Use edge info of parent quad element to set boundary curve flags
!              and names for the new hex element
!              ----------------------------------------------------------------
!
               DO k = 1, 4 
                  IF ( currentQuadElement % boundaryInfo % bCurveFlag(k) == ON )     THEN
                     hex8Mesh % elements(quadElementID,j) % bFaceFlag(flagMap(k)) = ON 
                     hex8Mesh % elements(quadElementID,j) % bFaceFlag(3) = ON 
                     hex8Mesh % elements(quadElementID,j) % bFaceFlag(5) = ON 
                  END IF 
                  hex8Mesh % elements(quadElementID,j) % bFaceName(flagMap(k)) &
                                      = currentQuadElement % boundaryInfo % bCurveName(k)
               END DO 
               
               quadElementID  = quadElementID + 1
               elementID      = elementID + 1
               
               CALL quadMesh % elementsIterator % moveToNext()
            END DO 
            
         END DO 
!
      END SUBROUTINE sweepElements
!
!//////////////////////////////////////////////////////////////////////// 
! 
      FUNCTION extrudedNodeLocation(baseLocation,delta,pmutation)  RESULT(x)
         IMPLICIT NONE  
         REAL(KIND=RP) :: baseLocation(3), delta
         INTEGER       :: pmutation
         REAL(KIND=RP) :: x(3)
               
         x              = baseLocation
         x(pmutation)   = delta 
      END FUNCTION extrudedNodeLocation
!
!//////////////////////////////////////////////////////////////////////// 
! 
      FUNCTION rotatedNodeLocation(baseLocation,theta,rotAxis)  RESULT(x)
         IMPLICIT NONE  
         REAL(KIND=RP) :: baseLocation(3), theta
         INTEGER       :: rotAxis
         REAL(KIND=RP) :: x(3)
         REAL(KIND=RP) :: r
               
         x              = baseLocation
         SELECT CASE ( rotAxis )
            CASE( 1 ) ! rotation about x-Axis
               r    = baseLocation(2)
               x(2) = r*COS(theta)
               x(3) = r*SIN(theta)
            CASE (2)  ! rotation about y-Axix
               r    = baseLocation(1)
               x(1) = r*COS(theta)
               x(3) = r*SIN(theta)
            CASE (3)  ! rotation about z-Axis
               r    = baseLocation(2)
               x(2) = r*COS(theta)
               x(1) = r*SIN(theta)
            CASE DEFAULT 
         END SELECT 
         
      END FUNCTION rotatedNodeLocation
!
!//////////////////////////////////////////////////////////////////////// 
! 
      FUNCTION permutePosition(x, pmutation)  RESULT(y)
         IMPLICIT NONE  
         REAL(KIND=RP), DIMENSION(3) :: x, y
         INTEGER                     :: pmutation
         
         y  = CSHIFT(x, SHIFT = -pmutation)

      END FUNCTION permutePosition
!
!//////////////////////////////////////////////////////////////////////// 
! 
      SUBROUTINE RotateAll(mesh, N, rotAxis)  
        IMPLICIT NONE  
!
!       ----------
!       Arguments 
!       ----------
!
        TYPE(StructuredHexMesh) :: mesh
        INTEGER                 :: rotAxis
        INTEGER                 :: N
!
!       ---------------
!       Local Variables
!       ---------------
!
         INTEGER       :: rotMap(3) = [3, 3, 1]
         INTEGER       :: k, j, i, l, m
         REAL(KIND=RP) :: rotated(3)
!
!        ----------------
!        Rotate the nodes
!        ----------------
!
         DO l = 0, SIZE(mesh % nodes,2)-1
            DO m = 1, SIZE(mesh % nodes,1)
               rotated = rotatedNodeLocation(baseLocation = mesh % nodes(m,l) % x,            &
                                             theta        = mesh % nodes(m,l) % x(rotMap(rotAxis)), &
                                             rotAxis    = rotAxis)
               mesh % nodes(m,l) % x = rotated
            END DO   
         END DO  
!
!        -----------------------------------
!        Rotate the internal DOFs
!        With rotation, all faces are curved
!        -----------------------------------
!
         DO l = 1, mesh % numberofLayers             ! level
            DO m = 1, mesh % numberOfQuadElements    ! element on original quad mesh
               mesh % elements(m,l) % bFaceFlag = ON
               DO k = 0, N 
                  DO j = 0, N 
                     DO i = 0, N 
                        rotated = rotatedNodeLocation(baseLocation = mesh % elements(m,l) % x(:,i,j,k), &
                                                      theta        = mesh % elements(m,l) % x((rotMap(rotAxis)),i,j,k),  &
                                                      rotAxis      = rotAxis)
                        mesh % elements(m,l) % x(:,i,j,k) = rotated
                     END DO 
                  END DO 
               END DO 
            END DO 
         END DO
        
      END SUBROUTINE RotateAll

      END Module SimpleSweepModule 