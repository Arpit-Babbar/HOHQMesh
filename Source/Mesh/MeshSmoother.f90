!
!////////////////////////////////////////////////////////////////////////
!
!      MeshSmoother.f90
!      Created: May 29, 2014 at 3:38 PM 
!      By: David Kopriva  
!
!      BASE CLASS FOR SMOOTHERS
!
!////////////////////////////////////////////////////////////////////////
!
      Module MeshSmootherClass
      USE SMMeshClass
      USE SMModelClass
      USE MeshBoundaryMethodsModule
      IMPLICIT NONE 
      
      TYPE :: MeshSmoother
!         
!        ========
         CONTAINS
!        ========
!         
         PROCEDURE  :: smoothMesh
         FINAL      :: destruct
      END TYPE MeshSmoother
!
!     ========
      CONTAINS
!     ========
!
!//////////////////////////////////////////////////////////////////////// 
! 
      SUBROUTINE CollectBoundaryAndInterfaceNodes(allNodesIterator,boundaryNodesList)
         IMPLICIT NONE
!
!        ---------
!        Arguments
!        ---------
!
         TYPE (FTLinkedListIterator), POINTER :: allNodesIterator
         CLASS(FTLinkedList)        , POINTER :: boundaryNodesList
!
!        ---------------
!        Local variables
!        ---------------
!
         CLASS(SMNode)  , POINTER :: currentNode => NULL()
         CLASS(FTObject), POINTER :: obj => NULL()
!
!        ------------------------------------------------------
!        Loop through all the nodes and add those whose
!        distance to a boundary is zero to the boundaryNodeList
!        ------------------------------------------------------
!
         CALL allNodesIterator % setToStart()
         DO WHILE ( .NOT.allNodesIterator % isAtEnd() )
            obj => allNodesIterator % object()
            CALL cast(obj,currentNode)
            IF ( IsOnBoundaryCurve(currentNode) .AND. &
                 currentNode%distToBoundary == 0.0_RP )     THEN
               CALL boundaryNodesList % add(obj)
            END IF 
            CALL allNodesIterator % moveToNext()
         END DO

      END SUBROUTINE CollectBoundaryAndInterfaceNodes
!
!//////////////////////////////////////////////////////////////////////// 
! 
      SUBROUTINE destruct( self )
         IMPLICIT NONE
         TYPE (MeshSmoother)   :: self
      END SUBROUTINE destruct
!
!//////////////////////////////////////////////////////////////////////// 
! 
      SUBROUTINE smoothMesh( self, mesh, model, errorCode )
         IMPLICIT NONE
         CLASS (MeshSmoother)          :: self
         TYPE  (SMMesh)      , POINTER :: mesh
         TYPE  (SMModel)     , POINTER :: model
         INTEGER                       :: errorCode
      END SUBROUTINE smoothMesh
      
      END MODULE MeshSmootherClass
